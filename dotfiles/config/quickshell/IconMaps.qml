pragma Singleton
import QtQuick

QtObject {
    // Volume — Nerd Font Material icons
    function volumeIcon(volPct, muted) {
        if (muted) return "\u{f075f}"
        if (volPct >= 66) return "\u{f057e}"
        if (volPct >= 33) return "\u{f0580}"
        if (volPct > 0)   return "\u{f057f}"
        return "\u{f075f}"
    }

    // Battery (0..100, charging bool)
    function batteryIcon(pct, charging) {
        if (charging) {
            if (pct >= 90) return "\u{f0084}"
            if (pct >= 60) return "\u{f0082}"
            if (pct >= 30) return "\u{f0081}"
            return "\u{f0083}"
        }
        if (pct >= 90) return "\u{f0079}"
        if (pct >= 80) return "\u{f0082}"
        if (pct >= 60) return "\u{f0080}"
        if (pct >= 40) return "\u{f007e}"
        if (pct >= 20) return "\u{f007b}"
        if (pct >= 10) return "\u{f007a}"
        return "\u{f008e}"
    }

    // Wi-Fi signal (0..100)
    function wifiIcon(signal, connected) {
        if (!connected) return "\u{f092f}"
        if (signal >= 75) return "\u{f0928}"
        if (signal >= 50) return "\u{f0925}"
        if (signal >= 25) return "\u{f0922}"
        if (signal > 0)   return "\u{f091f}"
        return "\u{f092f}"
    }

    // Bluetooth
    function bluetoothIcon(connected, discovering) {
        if (discovering) return "\u{f00af}"
        if (connected)   return "\u{f00b1}"
        return "\u{f00af}"
    }
}
