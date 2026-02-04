# Hyprland Configuration

## Machine-Specific Settings

**Always put machine-specific configs in `parts/extra.conf`** to avoid git conflicts when pulling updates.

`extra.conf` is sourced **last**, so it can override any defaults from the main config.

---

## Why This Works

```bash
# Main config (hyprland.conf) sets defaults for all machines
decoration {
    blur { enabled = true }
}

# Your extra.conf overrides for your specific machine
decoration {
    blur { enabled = false }  
}
```

Since `extra.conf` is sourced last, your settings win.

---

## Workflow

```bash
git pull  # Get repo updates
# No conflicts! extra.conf is not tracked
hyprctl reload  # Apply changes
```

---

## Files

| File | Purpose | Git Tracked |
|------|---------|-------------|
| `hyprland.conf` | Default settings | ✅ Yes |
| `parts/extra.conf` | Your overrides | ❌ No |
| `monitors.conf` | Monitor config | ❌ No |

---
