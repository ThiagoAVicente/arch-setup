#!/usr/bin/env python3
"""Show games Discord can't detect as their real, verified Discord app.

Discord matches running processes against its own list of game executables.
Some games (e.g. Phantom Blade Zero) have no executables registered there, so
they show up as an unverified "?" game or not at all. This watches /proc for
processes from a small map and sends the activity over Discord's local RPC
socket with the game's official application id, so Discord shows the real
name, icon and play time.

Map: ~/.config/game-presence.json   {"<exe name>": "<discord application id>"}
Exe names are matched case-insensitively against the process's argv[0]
basename (Proton paths like Z:\\...\\Game.exe included); ".exe" is optional.
Application ids: https://discord.com/api/v9/applications/detectable

No dependencies (stdlib only); polls every few seconds and sleeps otherwise.
"""

import json
import os
import socket
import struct
import sys
import time
import uuid

POLL_SECONDS = 5
CONFIG = os.path.join(
    os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"),
    "game-presence.json",
)
SEED = {"pbz.exe": "1566301629798424648"}  # Phantom Blade Zero

OP_HANDSHAKE, OP_FRAME, OP_CLOSE = 0, 1, 2


def log(*args):
    print("game-presence:", *args, file=sys.stderr, flush=True)


def load_map():
    if not os.path.exists(CONFIG):
        with open(CONFIG, "w") as f:
            json.dump(SEED, f, indent=2)
            f.write("\n")
        log("created", CONFIG)
    try:
        with open(CONFIG) as f:
            raw = json.load(f)
    except (OSError, ValueError) as e:
        log("bad config:", e)
        return {}
    return {norm(k): str(v) for k, v in raw.items()}


def norm(name):
    name = name.lower()
    return name[:-4] if name.endswith(".exe") else name


def running(names):
    """Return (exe, pid) of the first running process whose exe is in names."""
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                argv0 = f.read().split(b"\0", 1)[0].decode(errors="replace")
        except OSError:
            continue
        exe = norm(argv0.replace("\\", "/").rsplit("/", 1)[-1])
        if exe in names:
            return exe, int(pid)
    return None


class DiscordIPC:
    def __init__(self, client_id):
        self.sock = None
        runtime = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
        dirs = [runtime, f"{runtime}/app/com.discordapp.Discord", f"{runtime}/snap.discord", "/tmp"]
        for d in dirs:
            for i in range(10):
                path = f"{d}/discord-ipc-{i}"
                if not os.path.exists(path):
                    continue
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.settimeout(5)
                try:
                    s.connect(path)
                except OSError:
                    s.close()
                    continue
                self.sock = s
                self.send(OP_HANDSHAKE, {"v": 1, "client_id": client_id})
                self.recv()
                return
        raise ConnectionError("Discord is not running")

    def send(self, op, payload):
        assert self.sock
        data = json.dumps(payload).encode()
        self.sock.sendall(struct.pack("<II", op, len(data)) + data)

    def recv(self):
        assert self.sock
        header = self.sock.recv(8)
        if len(header) < 8:
            raise ConnectionError("Discord closed the connection")
        op, length = struct.unpack("<II", header)
        data = b""
        while len(data) < length:
            chunk = self.sock.recv(length - len(data))
            if not chunk:
                raise ConnectionError("Discord closed the connection")
            data += chunk
        reply = json.loads(data)
        if op == OP_CLOSE or reply.get("evt") == "ERROR":
            raise ConnectionError(reply.get("message") or reply.get("data"))
        return reply

    def set_activity(self, started):
        self.send(OP_FRAME, {
            "cmd": "SET_ACTIVITY",
            "args": {"pid": os.getpid(), "activity": {"timestamps": {"start": started}}},
            "nonce": str(uuid.uuid4()),
        })
        self.recv()

    def close(self):
        if self.sock:
            try:
                self.send(OP_CLOSE, {})
            except OSError:
                pass
            self.sock.close()
            self.sock = None


def main():
    ipc, current = None, None  # current = (exe, pid)
    while True:
        games = load_map()
        found = running(games)
        if found != current:
            if ipc and current:
                ipc.close()
                ipc = None
                log("cleared", current[0])
            current = None
            if found:
                try:
                    ipc = DiscordIPC(games[found[0]])
                    ipc.set_activity(int(time.time()))
                    current = found
                    log("playing", found[0], "as", games[found[0]])
                except (OSError, ConnectionError, ValueError) as e:
                    log("discord:", e)
                    if ipc:
                        ipc.close()
                    ipc = None
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
