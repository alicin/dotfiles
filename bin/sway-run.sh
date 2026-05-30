#! /bin/sh

# Set the environment variables

# BACKENDS
export SDL_VIDEODRIVER=wayland
export CLUTTER_BACKEND=wayland

# Session
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=sway
export XDG_CURRENT_DESKTOP=sway

# FRONTENDS
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export _JAVA_AWT_WM_NONREPARENTING=1

# # QT
# export QT_QPA_PLATFORM=wayland;xcb
# export QT_AUTO_SCREEN_SCALE_FACTOR=1
# export QT_SCALE_FACTOR=1
# export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
# export QT_QPA_PLATFORMTHEME=qt5ct

# # GDK
# export GDK_SCALE=2
# export GDK_BACKEND=wayland,x11,*

# ELECTRON
export ELECTRON_OZONE_PLATFORM_HINT=wayland

# start sway
exec sway "$@"