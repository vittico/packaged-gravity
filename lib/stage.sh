# shellcheck shell=bash
#
# stage.sh - assemble a clean FHS install tree that both the .rpm and .deb
# builders package verbatim. The tree mirrors what ends up on the user's disk:
#
#   /opt/<id>/...                      the unpacked Electron application
#   /usr/bin/<id>                      thin launcher script
#   /usr/share/applications/<id>.desktop
#   /usr/share/icons/hicolor/<size>/apps/<id>.png
#   /usr/share/pixmaps/<id>.png
#   /usr/share/doc/<id>/copyright
#
# All paths are rooted at $STAGE.

# stage_application <tarball> <stage-root>
# Unpacks the app into /opt/<id> and fixes up the few files that need special
# treatment (the setuid chrome-sandbox helper).
stage_application() {
  local tarball="$1" stage="$2"
  local optdir="$stage/opt/$AG_ID"

  log "Unpacking application into /opt/$AG_ID"
  mkdir -p "$stage/opt"
  # Extract into a scratch dir first because the in-tarball folder name
  # ("Antigravity IDE", "Antigravity-x64") differs from our install id.
  local scratch="$WORK/unpack"
  rm -rf "$scratch"; mkdir -p "$scratch"
  tar -xzf "$tarball" -C "$scratch"
  mv "$scratch/$AG_TOPDIR" "$optdir"

  # chrome-sandbox must be setuid root or Chromium refuses to start the
  # sandbox. We mark the bit here; the packagers force root:root ownership so
  # the installed file becomes a proper setuid-root helper.
  if [[ -f "$optdir/chrome-sandbox" ]]; then
    chmod 4755 "$optdir/chrome-sandbox"
  fi

  echo "$optdir"
}

# stage_launcher <stage-root>
# Installs a tiny wrapper on $PATH that execs the real binary in /opt. A wrapper
# (rather than a bare symlink) gives us a stable place to add flags later and
# matches what VS Code / Electron packages ship.
stage_launcher() {
  local stage="$1"
  mkdir -p "$stage/usr/bin"
  cat > "$stage/usr/bin/$AG_ID" <<EOF
#!/usr/bin/env bash
# Launcher for $AG_NAME (installed under /opt/$AG_ID).
exec "/opt/$AG_ID/$AG_EXEC" "\$@"
EOF
  chmod 0755 "$stage/usr/bin/$AG_ID"
}

# stage_desktop <stage-root>
# Writes a freedesktop .desktop entry. The IDE additionally advertises a
# directory MIME handler and a "New Window" action, mirroring VS Code.
stage_desktop() {
  local stage="$1"
  local dir="$stage/usr/share/applications"
  mkdir -p "$dir"
  {
    cat <<EOF
[Desktop Entry]
Name=$AG_NAME
Comment=$AG_COMMENT
GenericName=$AG_GENERIC
Exec=/usr/bin/$AG_ID %U
Icon=$AG_ID
Type=Application
StartupNotify=true
StartupWMClass=$AG_WMCLASS
Categories=$AG_CATEGORIES
EOF
    if [[ "$AG_PRODUCT" == ide ]]; then
      cat <<EOF
MimeType=text/plain;inode/directory;
Keywords=antigravity;ide;editor;
Actions=new-window;

[Desktop Action new-window]
Name=New Window
Exec=/usr/bin/$AG_ID --new-window %F
Icon=$AG_ID
EOF
    fi
  } > "$dir/$AG_ID.desktop"
}

# stage_icons <stage-root> <optdir>
# Locates the product's source PNG, renders the standard hicolor sizes (when
# ImageMagick is available) and drops a pixmaps fallback. GNOME picks these up
# via the icon name set in the .desktop file.
stage_icons() {
  local stage="$1" optdir="$2" src=""

  case "$AG_PRODUCT" in
    ide)
      src="$optdir/resources/app/resources/linux/code.png"
      ;;
    agent)
      # The agent's icon lives inside the asar; extract it to a temp file.
      src="$WORK/agent-icon.png"
      python3 "$LIB_DIR/asar.py" extract "$optdir/resources/app.asar" icon.png "$src" \
        || warn "could not extract icon from app.asar"
      ;;
  esac

  if [[ ! -f "$src" ]]; then
    warn "no source icon found; the app will use a generic icon"
    return 0
  fi

  # Prefer ImageMagick 7's `magick`; fall back to the older `convert`.
  local magick=""
  have magick && magick="magick"
  [[ -z "$magick" ]] && have convert && magick="convert"

  local hroot="$stage/usr/share/icons/hicolor"
  if [[ -n "$magick" ]]; then
    local size
    for size in 16 24 32 48 64 128 256 512; do
      mkdir -p "$hroot/${size}x${size}/apps"
      "$magick" "$src" -resize "${size}x${size}" "$hroot/${size}x${size}/apps/$AG_ID.png"
    done
  else
    # No ImageMagick: install the icon once at its native size.
    local dim="512"
    have identify && dim=$(identify -format '%w' "$src" 2>/dev/null || echo 512)
    mkdir -p "$hroot/${dim}x${dim}/apps"
    cp "$src" "$hroot/${dim}x${dim}/apps/$AG_ID.png"
  fi

  mkdir -p "$stage/usr/share/pixmaps"
  cp "$src" "$stage/usr/share/pixmaps/$AG_ID.png"
}

# stage_docs <stage-root> <optdir>
# Ships a copyright/notice file so the package is self-describing.
stage_docs() {
  local stage="$1" optdir="$2"
  local docdir="$stage/usr/share/doc/$AG_ID"
  mkdir -p "$docdir"
  cat > "$docdir/copyright" <<EOF
$AG_NAME $AG_VERSION

This package was assembled from Google's official Antigravity Linux release
using the packaged-gravity packaging scripts (https://github.com/vittico/packaged-gravity).

The Antigravity application is proprietary software owned by Google. The
packaging scripts themselves are MIT licensed; redistribution of the packaged
binaries is subject to Google's terms.
EOF
  # Preserve any upstream licence text shipped in the tarball.
  local lic
  for lic in LICENSE.txt LICENSE LICENSE.electron.txt; do
    [[ -f "$optdir/$lic" ]] && cp "$optdir/$lic" "$docdir/" 2>/dev/null || true
  done
}

# build_stage <tarball>
# Orchestrates a full staging pass. Sets the global $STAGE to the tree root.
build_stage() {
  local tarball="$1"
  STAGE="$WORK/stage"
  rm -rf "$STAGE"; mkdir -p "$STAGE"

  local optdir; optdir=$(stage_application "$tarball" "$STAGE")

  # Now that the app is unpacked we can read its real version (unless the user
  # forced one) and its architecture. Everything below may embed these.
  AG_VERSION="${FORCE_VERSION:-$(detect_version "$optdir")}"
  detect_arch "$optdir/$AG_EXEC"
  ok "Detected: $AG_NAME $AG_VERSION ($AG_ARCH_RPM)  (package id: $AG_ID)"

  stage_launcher "$STAGE"
  stage_desktop  "$STAGE"
  stage_icons    "$STAGE" "$optdir"
  stage_docs     "$STAGE" "$optdir"
  ok "Staged install tree at $STAGE"
}
