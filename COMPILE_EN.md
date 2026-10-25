# Building Plank (English)

Chinese version: [COMPILE_CN.md](COMPILE_CN.md). All package names and commands
below were verified on **Ubuntu 24.04 LTS (noble)**.

## 1. Build dependencies

The following modules are checked **unconditionally** at configure time (see
`PKG_CHECK_MODULES` in `configure.ac`); missing any one of them fails configure:

| Dependency | Minimum | apt package |
|---|---|---|
| glib / gobject / gio / gio-unix | 2.48.0 | `libglib2.0-dev` |
| gtk+3 / gdk-x11-3 | 3.10.0 | `libgtk-3-dev` |
| cairo | 1.13 | `libcairo2-dev` |
| gdk-pixbuf | 2.26.0 | `libgdk-pixbuf-2.0-dev` |
| libbamf3 | 0.4.0 | `libbamf3-dev` |
| libwnck-3 | — | `libwnck-3-dev` |
| gee-0.8 | — | `libgee-0.8-dev` |
| **x11** | — | **`libx11-dev`** |
| **libgnome-menu-3.0** | — | **`libgnome-menu-3-dev`** |

Toolchain: `autoconf`, `automake`, `libtool`, `pkg-config`, `gettext` (the
`AM_GNU_GETTEXT` macro needs `autopoint`) and `valac`.

> `vapigen` and `glib-compile-resources` are **not separate packages**: the
> former ships inside `valac` (`/usr/bin/vapigen`), the latter inside
> `libglib2.0-dev-bin`. Listing them in an `apt install` command fails with
> *Unable to locate package* and aborts the whole command.

One-liner:

```bash
sudo apt install autoconf automake libtool pkg-config gettext valac \
  libglib2.0-dev libgtk-3-dev libcairo2-dev libgdk-pixbuf-2.0-dev \
  libbamf3-dev libwnck-3-dev libgee-0.8-dev libx11-dev libgnome-menu-3-dev
```

### Optional dependencies (build succeeds without them, features are lost)

| Feature | Packages | How to turn it off |
|---|---|---|
| Pointer barriers (edge hiding that survives the mouse being flung) | `libxi-dev` `libxfixes-dev` | `--disable-barriers` |
| Dynamic quicklists | `libdbusmenu-glib-dev` `libdbusmenu-gtk3-dev` | auto-detected; without them configure reports `Dbusmenu support: no` |
| Apport crash reports | no dev library, data files only | `--disable-apport` |

## 2. Configure, build, install

```bash
./autogen.sh --prefix=/usr      # generates configure and configures in one go
make -j$(nproc)
sudo make install
```

There is no `./bootstrap` in this repository, despite what the generic GNU
`INSTALL` text used to suggest. `autogen.sh` runs `aclocal --install` and
`autoreconf --force --install`, so it needs network access to fetch missing
macros.

## 3. Running and verifying

```bash
plank --version
```

To run the build tree without installing, **use the libtool wrapper
`./src/plank`** — it points `LD_LIBRARY_PATH` at `lib/.libs`. Running
`src/.libs/plank` directly picks up an already installed `libplank.so.1`
instead. Proof:

```bash
LD_DEBUG=libs ./src/plank --version 2>&1 | grep 'libplank.so.1 =>'
```

(`=>` lines are only emitted by `LD_DEBUG=libs`; an empty result from
`LD_DEBUG=files` does not mean loading failed.)

For debugging: `gdb --args ./src/plank -d`.

## 4. Runtime dependency: bamfdaemon (important)

**Running-application icons come entirely from the libbamf3 window matcher.**
On Ubuntu 22.04/24.04 `libbamf3` is only a D-Bus client; it needs the
`org.ayatana.bamf` service on the session bus, which is provided by
**`bamfdaemon`** — and `libbamf3-dev` does *not* depend on it (the distro
`libplank1` package does).

Symptom: the dock starts fine but shows only pinned launchers, no running apps.

Fix:

```bash
sudo apt install bamfdaemon     # activated on demand via a system D-Bus service file
```

Diagnosis: ask the matcher directly through gir1.2-bamf-3. If it reports
`The name org.ayatana.bamf was not provided by any .service files` and returns
0 applications while `wmctrl -l` lists a dozen windows, this is the cause.

Note also that plank filters out `_NET_WM_WINDOW_TYPE_DOCK` windows (so
xfce4-panel never appears in the dock) and never shows itself.

## 5. Where the version number comes from

While `plank_released` is 0, the version is derived by
`build-aux/git-version-gen` from `git describe` (e.g. `0.11.89.31-6ce2`).
**Editing the m4 version components in `configure.ac` alone changes nothing.**
Two correct options:

- release: tag the commit (`git tag 0.12`), `git describe` then yields `0.12`;
- local pin: put `0.12` into `.tarball-version` at the top of the tree (the
  script reads that file before it looks at git).

## 6. Known traps

- **After editing a docklet's `.vala`, one `make -j8` does not relink the
  `.so`.** VALAC regenerates the `.c`, but the same recursive make pass skips
  CCLD. Run `make` again.
- `automake --force-missing` (called via `autogen.sh`) overwrites tracked
  auxiliary files. This tree now uses `AM_INIT_AUTOMAKE([foreign ...])`, so
  `INSTALL` is no longer required and has been deleted — it was generic GNU
  boilerplate whose first documented step does not even work here.
- `make clean` does **not** remove `po/*.gmo`, so total warning counts differ
  between rebuilds just because msgfmt did not re-run. Compare the set of
  C/Vala warnings, not the count.
- Running `sudo make install` (or letting apt replace libgtk/libbamf3/…) while
  the dock is live swaps out mmap'd libraries — a classic SIGBUS/SIGSEGV. Stop
  the dock first.

## 7. Building a .deb

```bash
sudo apt install debhelper dpkg-dev build-essential fakeroot
dpkg-buildpackage -us -uc -b          # artefacts land in the parent directory
```

`debian/` produces **one** runtime package, `plank` (the dock, libplank, the
seven docklets, the themes and the translations), plus an optional `-dbgsym`
carrying debug symbols for crash analysis only.  There is no `libplank1` or
`libplank-common` split and no development files at all (headers, `.pc`,
`.vapi` — see `debian/not-installed`): an `Architecture: all` data package
saves nothing when only amd64 is ever built, and as long as no headers ship,
nothing outside the tree can link against the library.  That also means
`sudo apt install ./plank_0.12-2_amd64.deb` is one self-contained command, with
no sibling .deb files to feed it.
