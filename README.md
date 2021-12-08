# Tasks
[![Translation status](https://l10n.elementary.io/widgets/tasks/-/svg-badge.svg)](https://l10n.elementary.io/engage/tasks/?utm_source=widget)

![Screenshot](https://raw.githubusercontent.com/elementary/tasks/master/data/screenshot.png)

## Building and Installation

You'll need the following dependencies:
* glib-2.0
* gobject-2.0
* granite >=6.2.0
* gtk+-3.0
* libchamplain-0.12-dev
* libchamplain-gtk-0.12-dev
* libclutter-1.0-dev
* libclutter-gtk-1.0-dev
* libecal-2.0
* libedataserver-1.2
* libgdata-dev
* libgeoclue-2-dev
* libgeocode-glib-dev
* libhandy-1-dev >= 0.90.0
* libical
* meson
* valac

Run `meson build` to configure the build environment. Change to the build directory and run `ninja` to build

```bash
meson build --prefix=/usr
cd build
ninja
```

To install, use `ninja install`, then execute with `io.elementary.tasks`

```bash
ninja install
io.elementary.tasks
```
