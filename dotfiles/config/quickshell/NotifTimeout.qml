pragma Singleton

import Quickshell
import Quickshell.Services.Notifications

// Shared expiry rules so the sweep timer and the progress bar agree
Singleton {
    function persistent(n) {
        if (!n) return false
        return n.expireTimeout === 0 || n.urgency === NotificationUrgency.Critical
    }

    function ms(n) {
        return n && n.expireTimeout > 0 ? n.expireTimeout : 5000
    }
}
