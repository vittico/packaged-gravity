# Contributing

Thanks for your interest in improving **packaged-gravity**!

## Ground rules

- **Never commit the Antigravity tarballs or built packages.** They are Google's
  proprietary binaries. `.gitignore` already excludes `*.tar.gz` and `dist/`.
- Keep the project **dependency-light**. The build is plain Bash plus widely
  available tools (`python3`, `rpmbuild`, `dpkg-deb`, `appimagetool`,
  ImageMagick). Please don't introduce heavyweight runtimes or language
  toolchains.
- Match the existing style: small focused functions, `lib/<area>.sh` modules,
  and comments that explain *why*, not *what*.

## Development setup

```bash
# Lint shell scripts (recommended)
shellcheck build.sh lib/*.sh

# Syntax-only check (no extra tools)
bash -n build.sh && for f in lib/*.sh; do bash -n "$f"; done

# Build against a tarball, keeping the work tree to inspect it
./build.sh Antigravity.tar.gz --keep
```

## How the pieces fit together

`build.sh` orchestrates these phases, each in its own module:

1. `lib/detect.sh` — identify product (agent/IDE), version and architecture.
2. `lib/stage.sh` — assemble one FHS install tree under a temp dir.
3. `lib/rpm.sh` / `lib/deb.sh` / `lib/appimage.sh` / `lib/flatpak.sh` — package
   that tree, unchanged, into each format.

Because every packager consumes the **same** staged tree, a fix in `stage.sh`
benefits all formats at once. Prefer changing the staging step over
special-casing a single format.

## Good first issues / wishlist

- **arm64** testing on real hardware (the code is arch-aware but only x86-64 has
  been exercised).
- Hardening / testing the **Flatpak** path (it's currently experimental).
- Arch **`PKGBUILD`** output.
- Auto-generated `.deb` dependencies via `dpkg-shlibdeps`.
- A `--sign` option (GPG for rpm, `dpkg-sig` for deb).

Open an issue to discuss larger changes before sending a PR. 🚀
