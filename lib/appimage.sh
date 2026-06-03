# shellcheck shell=bash
#
# appimage.sh - turn the staged tree into a self-contained .AppImage.
#
# An AppImage is a single executable file that runs on practically any Linux
# distribution without installation: the user just `chmod +x` it and runs it.
# That makes it a nice complement to the .rpm/.deb (which integrate with the
# system package manager). There is no system-wide upgrade mechanism for a bare
# AppImage - the user replaces the file - but tools like AppImageUpdate and the
# app's own updater can handle that.
#
# We reuse the same FHS staging tree and wrap it in an AppDir.

# _find_appimagetool
# Resolve an appimagetool binary: $APPIMAGETOOL, then PATH, then our cached copy
# under .tools/, downloading it once if necessary and possible.
_find_appimagetool() {
  if [[ -n "${APPIMAGETOOL:-}" && -x "${APPIMAGETOOL}" ]]; then
    echo "$APPIMAGETOOL"; return 0
  fi
  if have appimagetool; then command -v appimagetool; return 0; fi

  local cache="$SCRIPT_DIR/.tools/appimagetool"
  if [[ -x "$cache" ]]; then echo "$cache"; return 0; fi

  # Not found anywhere - fetch the official static build once.
  have curl || have wget || die "appimagetool not found and neither curl nor wget is available to download it"
  mkdir -p "$SCRIPT_DIR/.tools"
  local url="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${AG_ARCH_APPIMAGE}.AppImage"
  info "Downloading appimagetool ($AG_ARCH_APPIMAGE)…"
  if have curl; then curl -fsSL -o "$cache" "$url"; else wget -qO "$cache" "$url"; fi
  chmod +x "$cache"
  echo "$cache"
}

# _run_appimagetool <tool> <appdir> <output>
# Runs the tool, transparently falling back to self-extraction when FUSE is
# unavailable (common in containers and CI).
_run_appimagetool() {
  local tool="$1" appdir="$2" out="$3"
  if ARCH="$AG_ARCH_APPIMAGE" "$tool" "$appdir" "$out" >/dev/null 2>&1; then
    return 0
  fi
  ARCH="$AG_ARCH_APPIMAGE" "$tool" --appimage-extract-and-run "$appdir" "$out" >/dev/null
}

# build_appimage <outdir>
build_appimage() {
  local outdir="$1"
  local tool; tool="$(_find_appimagetool)"

  # Assemble the AppDir by hard-linking the (large) staged payload.
  local appdir="$WORK/AppDir"
  rm -rf "$appdir"
  mkdir -p "$appdir"
  cp -al "$STAGE/opt" "$appdir/opt"
  cp -al "$STAGE/usr" "$appdir/usr"

  # AppRun is the entry point the AppImage runtime executes. chrome-sandbox
  # cannot be setuid inside the read-only mount, so - like every other Electron
  # AppImage - we start with --no-sandbox.
  cat > "$appdir/AppRun" <<EOF
#!/bin/bash
HERE="\$(dirname "\$(readlink -f "\${0}")")"
export PATH="\$HERE/usr/bin:\$PATH"
exec "\$HERE/opt/$AG_ID/$AG_EXEC" --no-sandbox "\$@"
EOF
  chmod 0755 "$appdir/AppRun"

  # appimagetool expects a .desktop and a matching icon at the AppDir root.
  # The Exec here is informational (AppRun is what actually launches); keep it
  # path-free so desktop integration tools resolve it correctly.
  sed 's#^Exec=/usr/bin/#Exec=#' \
    "$STAGE/usr/share/applications/$AG_ID.desktop" > "$appdir/$AG_ID.desktop"

  local icon; icon="$(_appdir_icon "$appdir")"
  cp "$icon" "$appdir/$AG_ID.png"
  cp "$icon" "$appdir/.DirIcon"

  log "Building AppImage ($AG_ID $AG_VERSION $AG_ARCH_APPIMAGE)"
  mkdir -p "$outdir"
  local out="$outdir/${AG_NAME// /-}-${AG_VERSION}-${AG_ARCH_APPIMAGE}.AppImage"
  _run_appimagetool "$tool" "$appdir" "$out"
  chmod +x "$out"
  ok "AppImage: $out"
}

# _appdir_icon <appdir> - pick the largest installed PNG to use as the AppIcon.
_appdir_icon() {
  local appdir="$1" p
  for p in 512 256 128 64 48; do
    local f="$appdir/usr/share/icons/hicolor/${p}x${p}/apps/$AG_ID.png"
    [[ -f "$f" ]] && { echo "$f"; return 0; }
  done
  # Fallback to the pixmaps copy.
  echo "$appdir/usr/share/pixmaps/$AG_ID.png"
}
