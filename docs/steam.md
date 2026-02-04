# Steam Launch Options (NVIDIA GPU)

**NOTE**: `prime-run` will run apps on xwayland.

## Normal Games (with NVIDIA)

```bash
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia DXVK_STATE_CACHE=1 %command%
```

---

## Competitive FPS Games (No VSync)

```bash
__GL_SYNC_TO_VBLANK=0 VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia DXVK_STATE_CACHE=1 %command%
```

---

## SteamDeck Mode (with NVIDIA)

```bash
SteamDeck=1 VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia DXVK_STATE_CACHE=1 %command%
```

---

## SteamDeck + No VSync

```bash
__GL_SYNC_TO_VBLANK=0 SteamDeck=1 VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia DXVK_STATE_CACHE=1 %command%
```

---

## Quick Reference

| Type | VSync | SteamDeck | Command |
|------|-------|-----------|---------|
| Normal | On | No | Section 1 |
| FPS | Off | No | Section 2 |
| Normal | On | Yes | Section 3 |
| FPS | Off | Yes | Section 4 |
