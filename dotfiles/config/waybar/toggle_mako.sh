#!/bin/bash

# Get current state
STATE=$(makoctl mode)

if [ "$STATE" = "do-not-disturb" ]; then
  makoctl mode -s default
else
  makoctl mode -s do-not-disturb
fi
