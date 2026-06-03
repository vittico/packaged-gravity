# shellcheck shell=bash
#
# flatpak.sh - build a Flatpak bundle (EXPERIMENTAL).
#
# Flatpak is heavier than the other formats: it needs `flatpak-builder`, the
# freedesktop Platform/SDK runtime and the Electron BaseApp (which provides
# `zypak`, the shim that lets Chromium's sandbox work inside Flatpak's own
# sandbox). Those runtimes are large downloads from Flathub, so - unlike the
# rpm/deb/AppImage paths - this one is not exercised by the project's own tests.
# It generates a correct manifest and drives flatpak-builder; treat it as a
# solid starting point you may need to tune (especially `finish-args`).
#
# Upgrades work the normal Flatpak way: install the produced bundle, and a newer
# bundle with the same app-id and a higher version replaces it.

FLATPAK_RUNTIME_VERSION="${FLATPAK_RUNTIME_VERSION:-24.08}"

# build_flatpak <outdir>
build_flatpak() {
  local outdir="$1"
  require flatpak-builder "Install it with: sudo dnf install flatpak-builder (or apt install flatpak-builder)"

  local ctx="$WORK/flatpak"
  rm -rf "$ctx"; mkdir -p "$ctx/_pkg"

  # The application payload: hand flatpak-builder the original tarball.
  cp "$TARBALL" "$ctx/app.tar.gz"

  # zypak-wrapper makes Chromium's sandbox cooperate with Flatpak's sandbox.
  cat > "$ctx/_pkg/launcher.sh" <<EOF
#!/bin/sh
exec zypak-wrapper /app/opt/$AG_ID/$AG_EXEC "\$@"
EOF

  # Reuse the staged desktop entry, renamed to the Flatpak app-id and pointed at
  # the in-sandbox command. Icon is renamed to the app-id too, as Flatpak wants.
  sed -e "s#^Exec=/usr/bin/$AG_ID#Exec=$AG_ID#" \
      -e "s#^Icon=$AG_ID#Icon=$AG_FLATPAK_ID#" \
      "$STAGE/usr/share/applications/$AG_ID.desktop" > "$ctx/_pkg/$AG_FLATPAK_ID.desktop"
  cp "$(_flatpak_icon)" "$ctx/_pkg/$AG_FLATPAK_ID.png"

  _write_manifest > "$ctx/$AG_FLATPAK_ID.yml"

  log "Building Flatpak ($AG_FLATPAK_ID $AG_VERSION) — this pulls runtimes from Flathub"
  flatpak-builder --force-clean --repo="$ctx/repo" \
    --install-deps-from=flathub \
    "$ctx/build" "$ctx/$AG_FLATPAK_ID.yml"

  mkdir -p "$outdir"
  local bundle="$outdir/${AG_FLATPAK_ID}-${AG_VERSION}.flatpak"
  flatpak build-bundle "$ctx/repo" "$bundle" "$AG_FLATPAK_ID" "$AG_VERSION"
  ok "Flatpak: $bundle"
}

# _flatpak_icon - largest staged icon, falling back to pixmaps.
_flatpak_icon() {
  local p
  for p in 512 256 128 64 48; do
    local f="$STAGE/usr/share/icons/hicolor/${p}x${p}/apps/$AG_ID.png"
    [[ -f "$f" ]] && { echo "$f"; return 0; }
  done
  echo "$STAGE/usr/share/pixmaps/$AG_ID.png"
}

# _write_manifest - emit the flatpak-builder manifest on stdout.
_write_manifest() {
  cat <<EOF
app-id: $AG_FLATPAK_ID
runtime: org.freedesktop.Platform
runtime-version: '$FLATPAK_RUNTIME_VERSION'
sdk: org.freedesktop.Sdk
base: org.electronjs.Electron2.BaseApp
base-version: '$FLATPAK_RUNTIME_VERSION'
command: $AG_ID
separate-locales: false

finish-args:
  - --share=ipc
  - --share=network
  - --socket=x11
  - --socket=wayland
  - --socket=pulseaudio
  - --device=dri
  - --filesystem=home
  - --talk-name=org.freedesktop.Notifications
  - --talk-name=org.freedesktop.secrets

modules:
  - name: $AG_ID
    buildsystem: simple
    build-commands:
      - install -d /app/opt/$AG_ID
      - find . -maxdepth 1 -mindepth 1 ! -name _pkg -exec cp -a {} /app/opt/$AG_ID/ \;
      - install -Dm755 _pkg/launcher.sh /app/bin/$AG_ID
      - install -Dm644 _pkg/$AG_FLATPAK_ID.desktop /app/share/applications/$AG_FLATPAK_ID.desktop
      - install -Dm644 _pkg/$AG_FLATPAK_ID.png /app/share/icons/hicolor/512x512/apps/$AG_FLATPAK_ID.png
    sources:
      - type: archive
        path: app.tar.gz
        strip-components: 1
      - type: file
        path: _pkg/launcher.sh
        dest: _pkg
      - type: file
        path: _pkg/$AG_FLATPAK_ID.desktop
        dest: _pkg
      - type: file
        path: _pkg/$AG_FLATPAK_ID.png
        dest: _pkg
EOF
}
