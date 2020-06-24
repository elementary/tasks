# Tasks

## Building and Installation

You'll need the following dependencies:
* glib-2.0
* gobject-2.0
* granite >=0.5
* gtk+-3.0
* libecal1.2-dev
* libedataserver-1.2
* libedataserverui1.2-dev
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
