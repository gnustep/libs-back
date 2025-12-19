#!/bin/bash

# This script is used to regenerate xdg-shell-protocol public code and headers
# from the XML specification.

regen()
{
  wayland-scanner private-code \
    ${xmldir}/$1/$2.xml \
    Source/wayland/$1-protocol.c
  wayland-scanner client-header \
    ${xmldir}/$1/$2.xml \
    Headers/wayland/$1-client-protocol.h
}

xmldir=/usr/share/wayland-protocols/stable
regen 'xdg-shell' 'xdg-shell'

xmldir=/usr/share/wayland-protocols/staging

regen 'xdg-activation' 'xdg-activation-v1'

