#!/bin/sh
case "$(hostname)" in
    pc) ~/dev/config/screenlayout/pc.sh ;;
    *)  ~/dev/config/screenlayout/daisy.sh ;;
esac
