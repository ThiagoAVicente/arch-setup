#!/bin/bash

# Pega o caminho do wallpaper atual do swww
WALLPAPER=$(swww query | grep "currently displaying" | sed 's/.*image: //')

# Lock screen com blur leve
swaylock \
  -f \
  --screenshot \
  --effect-blur 5x5 \
  --indicator \
  --indicator-radius 80 \
  --indicator-thickness 7 \
  --inside-color 1e1e2e00 \
  --ring-color ffffff33 \
  --line-color ffffff00 \
  --key-hl-color ff5555ff \
  --separator-color 00000000 \
  --text-color ffffffff \
  --clock
