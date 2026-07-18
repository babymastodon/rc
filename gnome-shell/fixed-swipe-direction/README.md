# Fixed Swipe Direction

This is a temporary workaround for
[GNOME Shell issue #8787](https://gitlab.gnome.org/GNOME/gnome-shell/-/issues/8787).
It keeps three-finger Shell gestures in GNOME's normal physical direction when
the touchpad scroll direction is set to Traditional. Two-finger scrolling is
not changed.

It is installed and enabled with the other configured extensions:

```sh
./install_extensions.sh
```

A first-time installation requires a GNOME Shell restart or logout/login. The
installer queues the extension to be enabled after that restart.

The extension uses private GNOME Shell fields and declares compatibility with
GNOME Shell 49 and 50.
