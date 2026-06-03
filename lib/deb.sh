# shellcheck shell=bash
#
# deb.sh - turn the staged tree into a .deb using dpkg-deb.
#
# As with the RPM, upgrades are automatic: the Package name is stable and only
# the Version increases, so `apt upgrade` / `dpkg -i` replace the old release.

# build_deb <outdir>
build_deb() {
  local outdir="$1"
  require dpkg-deb "Install it with: sudo apt-get install dpkg (Debian/Ubuntu)"

  # dpkg-deb wants DEBIAN/ alongside the payload. Hard-link the (large) staged
  # tree into a deb-specific root so we don't copy gigabytes around.
  local root="$WORK/deb"
  rm -rf "$root"
  cp -al "$STAGE" "$root"
  mkdir -p "$root/DEBIAN"

  local installed_kb
  installed_kb=$(du -sk "$STAGE" | cut -f1)

  _write_control "$installed_kb" > "$root/DEBIAN/control"
  _write_maintscript postinst   > "$root/DEBIAN/postinst"
  _write_maintscript postrm     > "$root/DEBIAN/postrm"
  chmod 0755 "$root/DEBIAN/postinst" "$root/DEBIAN/postrm"

  log "Building DEB ($AG_ID $AG_VERSION $AG_ARCH_DEB)"
  local deb="$outdir/${AG_ID}_${AG_VERSION}_${AG_ARCH_DEB}.deb"
  mkdir -p "$outdir"
  # --root-owner-group makes every file root:root without needing fakeroot,
  # while preserving the setuid bit staged onto chrome-sandbox.
  dpkg-deb --root-owner-group --build "$root" "$deb" >/dev/null
  ok "DEB: $deb"
}

# _write_control <installed-size-kb>
_write_control() {
  cat <<EOF
Package: $AG_ID
Version: $AG_VERSION
Architecture: $AG_ARCH_DEB
Maintainer: packaged-gravity <packaging@localhost>
Installed-Size: $1
Section: devel
Priority: optional
Homepage: https://antigravity.google
Depends: libgtk-3-0 | libgtk-3-0t64, libnss3, libnotify4, libsecret-1-0, libasound2 | libasound2t64, libgbm1, libdrm2, libxkbcommon0, libatspi2.0-0 | libatspi2.0-0t64
Description: $AG_COMMENT
 $AG_NAME packaged from the official Google Antigravity Linux release.
 .
 It bundles its own Electron/Chromium runtime under /opt/$AG_ID and installs a
 launcher, desktop entry and icons so it behaves like any other desktop
 application and upgrades cleanly through apt.
EOF
}

# _write_maintscript postinst|postrm
# Refreshes the desktop database and icon cache after install/removal, and
# re-asserts the chrome-sandbox setuid bit defensively.
_write_maintscript() {
  cat <<EOF
#!/bin/sh
set -e

if [ -x /usr/bin/update-desktop-database ]; then
  update-desktop-database -q /usr/share/applications || true
fi
if [ -x /usr/bin/gtk-update-icon-cache ]; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
EOF
  if [[ "$1" == postinst ]]; then
    cat <<EOF
if [ -e /opt/$AG_ID/chrome-sandbox ]; then
  chmod 4755 /opt/$AG_ID/chrome-sandbox || true
fi
EOF
  fi
  echo "exit 0"
}
