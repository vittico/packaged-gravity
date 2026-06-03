<h1 align="center">📦 packaged-gravity</h1>

<p align="center">
  <em>Turn Google Antigravity's Linux <code>.tar.gz</code> releases into proper, upgradeable native packages —
  <strong>RPM</strong>, <strong>DEB</strong>, <strong>AppImage</strong> and <strong>Flatpak</strong>.</em>
</p>

<p align="center">
  <a href="#-buy-me-a-coffee"><img alt="Buy Me A Coffee" src="https://img.shields.io/badge/Buy%20me%20a%20coffee-%E2%98%95-FFDD00?style=flat-square"></a>
  <img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-green.svg?style=flat-square">
  <img alt="Shell" src="https://img.shields.io/badge/Made%20with-Bash-1f425f.svg?style=flat-square">
</p>

---

## Why this exists

[Google Antigravity](https://antigravity.google) ships for Linux as plain
`.tar.gz` archives. You can run them, but you get:

- ❌ no entry in your application menu, no icon
- ❌ no `antigravity` command on your `PATH`
- ❌ no integration with your distro's package manager — and therefore **no
  clean upgrade path**
- ❌ a `chrome-sandbox` that isn't set up correctly, so sandboxing may not work

**packaged-gravity** wraps those tarballs into real, first-class Linux packages
so Antigravity installs, launches, shows an icon, and **upgrades** like any other
application you'd get from your distribution.

It supports **both** Antigravity products and **auto-detects** which one you hand
it:

| Product | Tarball you download | Package name | Command |
| --- | --- | --- | --- |
| **Antigravity** (coding agent) | `Antigravity.tar.gz` | `antigravity` | `antigravity` |
| **Antigravity IDE** | `Antigravity IDE.tar.gz` | `antigravity-ide` | `antigravity-ide` |

It also figures out the **version** (e.g. `2.0.10` / `2.0.3`) and **CPU
architecture** straight from the binaries — you don't pass any of that by hand.

---

## ⚡ Quick start

```bash
git clone https://github.com/vittico/packaged-gravity.git
cd packaged-gravity

# Build the native packages (.rpm + .deb) — product & version auto-detected
./build.sh "Antigravity IDE.tar.gz"

# ...or pick exactly what you want
./build.sh Antigravity.tar.gz --format rpm
./build.sh Antigravity.tar.gz --format deb,appimage
./build.sh Antigravity.tar.gz --format all          # rpm + deb + appimage
```

Packages land in `./dist/`. Install with your normal tools:

```bash
# Fedora / RHEL / openSUSE
sudo dnf install ./dist/antigravity-2.0.10-1.fc44.x86_64.rpm

# Debian / Ubuntu
sudo apt install ./dist/antigravity_2.0.10_amd64.deb

# AppImage — no install needed, just make it executable
chmod +x ./dist/Antigravity-2.0.10-x86_64.AppImage
./dist/Antigravity-2.0.10-x86_64.AppImage
```

After installing the RPM/DEB you'll find **Antigravity** in your application
menu with its icon, and an `antigravity` (or `antigravity-ide`) command on your
`PATH`.

---

## 🎁 Output formats

Choose with `--format` (comma-separated lists are allowed):

| Format | Flag | Best for | Build tool needed | Upgrades via |
| --- | --- | --- | --- | --- |
| **RPM** | `rpm` | Fedora, RHEL, CentOS, openSUSE | `rpmbuild` | `dnf upgrade` |
| **DEB** | `deb` | Debian, Ubuntu, Mint, Pop!_OS | `dpkg-deb` | `apt upgrade` |
| **AppImage** | `appimage` | any distro, portable, no root | `appimagetool` (auto-downloaded) | replace the file / AppImageUpdate |
| **Flatpak** ⚗️ | `flatpak` | sandboxed, cross-distro | `flatpak-builder` + Flathub runtimes | `flatpak update` |
| `all` | `all` | rpm + deb + appimage | — | — |
| `native` *(default)* | `native` | rpm + deb | — | — |

> ⚗️ **Flatpak is experimental.** It produces a valid manifest and drives
> `flatpak-builder`, but it pulls large runtimes from Flathub and its sandbox
> permissions (`finish-args`) may need tuning for your setup. The RPM, DEB and
> AppImage paths are the well-tested ones.

You can build any format on any distro — e.g. produce `.deb`s on Fedora — as long
as the matching **build tool** is installed. The output architecture follows the
tarball: an x86-64 tarball yields `x86_64`/`amd64` packages; an arm64 tarball
yields `aarch64`/`arm64` packages, automatically.

---

## 🔄 Upgrades — the whole point

Every package keeps a **stable name** (`antigravity` / `antigravity-ide`) and
only its **version** changes. Both RPM and DEB compare versions numerically per
segment, so `2.0.10` correctly supersedes `2.0.3`. When a new Antigravity
release comes out:

```bash
./build.sh Antigravity.tar.gz          # build the new version
sudo dnf upgrade ./dist/antigravity-*.rpm    # clean in-place upgrade (Fedora)
sudo apt install ./dist/antigravity_*.deb    # clean in-place upgrade (Debian)
```

**Rolling it out to many machines.** Drop the packages into a repository and
your hosts pick up upgrades through their normal `dnf upgrade` / `apt upgrade`:

```bash
# RPM repo
createrepo_c /srv/repo/antigravity/      # then add a .repo file pointing at it

# DEB repo
reprepro -b /srv/apt includedeb stable ./dist/antigravity_2.0.10_amd64.deb
```

---

## 🧩 Dependencies

The build scripts are plain **Bash** plus a few common tools. `build.sh` checks
for what each step needs and prints a precise message (including the install
command) if something is missing — you'll never get a cryptic failure.

### Always required

| Tool | Why | Fedora | Debian/Ubuntu |
| --- | --- | --- | --- |
| `bash`, `tar`, coreutils | the build itself | *(base system)* | *(base system)* |
| `python3` | read versions; unpack the agent's `app.asar` | `python3` | `python3` |

### Required per output format

| Building… | Needs | Fedora | Debian/Ubuntu |
| --- | --- | --- | --- |
| `.rpm` | `rpmbuild` | `sudo dnf install rpm-build` | `sudo apt install rpm` |
| `.deb` | `dpkg-deb` | `sudo dnf install dpkg` | *(base system)* |
| `.AppImage` | `appimagetool` | *auto-downloaded to `.tools/`* | *auto-downloaded to `.tools/`* |
| `.flatpak` | `flatpak-builder` | `sudo dnf install flatpak-builder` | `sudo apt install flatpak-builder` |

### Optional

| Tool | Effect if present | Effect if absent |
| --- | --- | --- |
| ImageMagick (`magick`/`convert`) | renders icons at **all** sizes (16–512 px) | installs a single icon at its native size |

> The **runtime** dependencies of the app itself (GTK, NSS, ALSA, libsecret,
> libnotify, …) are declared inside the packages, so the package manager pulls
> them in automatically when a user installs.

---

## 📖 Usage reference

```text
./build.sh [options] <tarball>

Options:
  -f, --format <fmt>    rpm | deb | appimage | flatpak | all | native
                        (default: native = rpm + deb)  may be comma-separated
  -o, --outdir <dir>    output directory  (default: ./dist)
      --product <p>     force agent | ide (default: auto-detect)
      --version <v>     override the detected version
  -k, --keep            keep the temporary build tree (for debugging)
  -h, --help            show this help
```

### Examples

```bash
# Auto-detect everything, build rpm + deb
./build.sh "Antigravity IDE.tar.gz"

# Just an AppImage, into a custom directory
./build.sh Antigravity.tar.gz -f appimage -o /tmp/out

# Everything except flatpak
./build.sh Antigravity.tar.gz -f all

# Force the version (e.g. for testing the upgrade flow)
./build.sh Antigravity.tar.gz --version 2.0.99

# Keep the staging tree to inspect what got packaged
./build.sh Antigravity.tar.gz --keep
```

---

## 🔬 How it works

For each tarball, `build.sh` runs four phases — each lives in its own small
module under `lib/`:

1. **Detect** (`lib/detect.sh`) — identify the product (agent vs IDE), read the
   real version, and read the CPU architecture:
   - IDE → `resources/app/product.json` → `ideVersion`
   - agent → the `version` in the `package.json` inside `resources/app.asar`
     (read by the dependency-free `lib/asar.py`)
2. **Stage** (`lib/stage.sh`) — assemble **one** clean
   [FHS](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html) install
   tree that every packager consumes verbatim:
   ```
   /opt/<id>/...                                   the Electron app
   /usr/bin/<id>                                   launcher on $PATH
   /usr/share/applications/<id>.desktop            menu entry (+ "New Window" for the IDE)
   /usr/share/icons/hicolor/<size>/apps/<id>.png   GNOME/KDE icons (16–512 px)
   /usr/share/pixmaps/<id>.png                     fallback icon
   /usr/share/doc/<id>/copyright
   ```
   This phase also fixes `chrome-sandbox` to be **setuid-root** and extracts the
   agent's icon from inside its `app.asar`.
3. **Package** (`lib/rpm.sh`, `lib/deb.sh`, `lib/appimage.sh`, `lib/flatpak.sh`)
   — wrap that one staged tree into each requested format, with post-install
   scriptlets that refresh the desktop and icon caches.

Because all packagers share the same staged tree, the `.rpm`, `.deb`, and
`.AppImage` lay files down **identically** — a fix in staging benefits them all.

### Project layout

```
build.sh            entry point: parse args, detect, stage, build
lib/
  common.sh         logging + tool-detection helpers
  detect.sh         product / version / architecture detection + metadata
  asar.py           tiny dependency-free Electron ASAR reader (version + icon)
  stage.sh          assembles the FHS install tree
  rpm.sh            generates the .spec and runs rpmbuild
  deb.sh            generates DEBIAN/control + maintainer scripts, runs dpkg-deb
  appimage.sh       builds an AppDir and runs appimagetool
  flatpak.sh        generates a flatpak-builder manifest (experimental)
```

---

## ❓ Troubleshooting

- **`required tool 'rpmbuild' not found`** — install it (`sudo dnf install
  rpm-build`), or build a different format with `--format deb` / `appimage`.
- **The AppImage starts with `--no-sandbox`.** That's expected: `chrome-sandbox`
  can't be setuid inside an AppImage's read-only mount, so — like every Electron
  AppImage — it launches with the sandbox disabled. The RPM/DEB **do** ship a
  proper setuid sandbox.
- **Icons are low-res.** Install ImageMagick so the script can render every
  hicolor size.
- **Flatpak build fails pulling runtimes.** Make sure the Flathub remote is
  added: `flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo`.

---

## ☕ Buy me a coffee

If packaged-gravity saved you some time, you can say thanks — it's just a tip
jar, nothing here is gated or paywalled. ❤️

<p>
  <a href="https://www.buymeacoffee.com/vittico">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="48">
  </a>
</p>

---

## 🤝 Contributing

PRs and issues welcome! See [CONTRIBUTING.md](CONTRIBUTING.md). Especially wanted:
**arm64 testing**, a `--sign` option (GPG/`dpkg-sig`), and an Arch `PKGBUILD`.

---

## ⚖️ Licensing

The **packaging scripts in this repository are [MIT licensed](LICENSE).**

The **Antigravity application is proprietary software owned by Google.** This
project does **not** include, redistribute, or modify Antigravity — it only
repackages a tarball *you* download yourself. You are responsible for complying
with Google's terms when distributing the resulting packages. The repository's
`.gitignore` deliberately excludes `*.tar.gz` and `dist/` so you never commit
Google's binaries by accident.
