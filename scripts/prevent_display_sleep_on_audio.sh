#!/bin/sh
# This script prevents the display from sleeping via DPMS when audio is playing.
while true; do
  # Check if any audio stream is currently running using PipeWire.
  if pw-dump | grep -q '"state": "running"'; then
    # If audio is playing, reset the X server's idle timer.
    xset s reset
  fi
  # Check every 60 seconds.
  sleep 60
done
