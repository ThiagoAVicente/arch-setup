pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

// Synced lyrics for whatever Spotify is playing, from LRCLIB (lrclib.net, free,
// no account). Fetched once per track with curl and cached under
// ~/.cache/quickshell/lyrics, so a song heard before costs nothing. Shown in
// the lyrics drawer (bar/popouts/LyricsPopout.qml) while `shown` is on.
Singleton {
    id: lyrics

    // Spotify only: other players never get lyrics (or the pill)
    readonly property var player: Mpris.players.values.find(p =>
        (p.identity ?? "").toLowerCase().includes("spotify")
        || (p.dbusName ?? "").toLowerCase().includes("spotify")) ?? null
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""

    // Lyrics drawer open (set by Bar.qml); nothing is fetched or followed
    // while it is closed
    property bool shown: false

    // [{ t: seconds, text }] for the current track, empty if none were found
    property var lines: []
    readonly property bool available: lines.length > 0
    // Line being sung now ("" before the first line or in a gap), and the
    // lines either side of it
    property string line: ""
    property string prevLine: ""
    property string nextLine: ""
    // Index of that line in `lines` (-1 before the first)
    property int index: -1
    readonly property bool loading: fetch.running

    readonly property string cacheDir:
        (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") || "") + "/.cache")
        + "/quickshell/lyrics"

    // Fetched only while lyrics are switched on: when they are turned on, and
    // on each track change after that. Nothing runs while they're off
    readonly property string trackKey: artist + "\n" + title
    property string fetchedKey: ""
    onTrackKeyChanged: {
        lines = []
        line = ""
        fetchedKey = ""
        if (shown) load()
    }
    function load() {
        if (title === "" || artist === "" || fetchedKey === trackKey) return
        fetchedKey = trackKey
        fetch.running = false
        fetch.command = ["sh", "-c", fetch.script, "sh", cacheDir, artist, title,
            player?.trackAlbum ?? "", String(Math.round(player?.length ?? 0))]
        fetch.running = true
    }

    // "[mm:ss.xx]text" lines; untimed or metadata lines are skipped, and
    // per-word "<mm:ss.xx>" tags (enhanced LRC) are dropped
    function parse(lrc) {
        const out = []
        for (const raw of lrc.split("\n")) {
            const m = /^\[(\d+):(\d+(?:\.\d+)?)\](.*)$/.exec(raw.trim())
            if (!m) continue
            const text = m[3].replace(/<\d+:\d+(?:\.\d+)?>/g, "").replace(/\s+/g, " ").trim()
            out.push({ t: parseInt(m[1]) * 60 + parseFloat(m[2]), text: text })
        }
        return out.sort((a, b) => a.t - b.t)
    }

    function update() {
        if (!player || !available) { line = prevLine = nextLine = ""; index = -1; return }
        player.positionChanged()
        const pos = player.position + 0.15
        let i = -1
        while (i + 1 < lines.length && lines[i + 1].t <= pos) i++
        // Blank lines are pauses: show the lines around them, not a gap
        const near = (from, step) => {
            for (let k = from; k >= 0 && k < lines.length; k += step)
                if (lines[k].text !== "") return lines[k].text
            return ""
        }
        prevLine = i > 0 ? near(i - 1, -1) : ""
        nextLine = near(i + 1, 1)
        line = i >= 0 ? lines[i].text : ""
        index = i
    }

    // Prints the LRC text of the track, from the cache or LRCLIB; nothing if
    // LRCLIB has no synced lyrics for it
    Process {
        id: fetch
        readonly property string script: '
            dir=$1; artist=$2; title=$3; album=$4; dur=$5
            mkdir -p "$dir"
            key=$(printf "%s\\n%s" "$artist" "$title" | md5sum | cut -c1-32)
            f="$dir/$key.lrc"
            if [ ! -f "$f" ]; then
                ua="arch-setup quickshell bar (https://github.com/ThiagoAVicente/arch-setup)"
                json=$(curl -fsG --max-time 8 -A "$ua" "https://lrclib.net/api/get" \
                    --data-urlencode "artist_name=$artist" --data-urlencode "track_name=$title" \
                    --data-urlencode "album_name=$album" --data-urlencode "duration=$dur")
                lrc=$(printf "%s" "$json" | jq -r ".syncedLyrics // empty" 2>/dev/null)
                if [ -z "$lrc" ]; then
                    json=$(curl -fsG --max-time 8 -A "$ua" "https://lrclib.net/api/search" \
                        --data-urlencode "artist_name=$artist" --data-urlencode "track_name=$title")
                    lrc=$(printf "%s" "$json" | jq -r "[.[] | select(.syncedLyrics)][0].syncedLyrics // empty" 2>/dev/null)
                fi
                [ -n "$lrc" ] && printf "%s" "$lrc" > "$f"
                printf "%s" "$lrc"
            else
                cat "$f"
            fi'
        stdout: StdioCollector {
            onStreamFinished: lyrics.lines = lyrics.parse(text)
        }
    }

    // Follows the song only while lyrics are on screen
    Timer {
        interval: 250
        repeat: true
        running: lyrics.shown && lyrics.available && (lyrics.player?.isPlaying ?? false)
        onTriggered: lyrics.update()
    }
    onShownChanged: { if (shown) load(); update() }
    onLinesChanged: update()
}
