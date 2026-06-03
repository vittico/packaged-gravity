# shellcheck shell=bash
#
# detect.sh - figure out which Antigravity product a tarball contains and what
# its version is, then publish a consistent set of per-product metadata that
# the staging and packaging steps consume.
#
# Exposed variables (set by configure_product):
#   AG_PRODUCT     agent | ide
#   AG_ID          package / install name           e.g. antigravity-ide
#   AG_NAME        human readable name              e.g. "Antigravity IDE"
#   AG_EXEC        executable inside the package    e.g. antigravity-ide
#   AG_GENERIC     desktop GenericName
#   AG_COMMENT     desktop Comment / package summary
#   AG_CATEGORIES  desktop Categories (trailing ';')
#   AG_WMCLASS     desktop StartupWMClass
#   AG_TOPDIR      top-level directory inside the tarball
#   AG_VERSION     detected (or user supplied) version

# detect_product <tarball-listing-file>
# Echoes "agent" or "ide" based on the archive's fingerprint files.
detect_product() {
  local listing="$1"
  if grep -q 'resources/app/product.json' "$listing"; then
    echo ide
  elif grep -q 'resources/app\.asar' "$listing"; then
    echo agent
  else
    die "could not recognise this archive as the Antigravity agent or IDE"
  fi
}

# configure_product <product> <topdir>
# Populates the AG_* metadata for the detected product.
configure_product() {
  local product="$1" topdir="$2"
  AG_PRODUCT="$product"
  AG_TOPDIR="$topdir"
  case "$product" in
    agent)
      AG_ID="antigravity"
      AG_NAME="Antigravity"
      AG_EXEC="antigravity"
      AG_GENERIC="AI Coding Agent"
      AG_COMMENT="Antigravity — agentic AI coding assistant"
      AG_CATEGORIES="Development;"
      AG_WMCLASS="Antigravity"
      AG_FLATPAK_ID="com.google.Antigravity"
      ;;
    ide)
      AG_ID="antigravity-ide"
      AG_NAME="Antigravity IDE"
      AG_EXEC="antigravity-ide"
      AG_GENERIC="Text Editor"
      AG_COMMENT="Antigravity IDE — AI-native code editor"
      AG_CATEGORIES="Development;IDE;TextEditor;"
      AG_WMCLASS="Antigravity IDE"
      AG_FLATPAK_ID="com.google.AntigravityIDE"
      ;;
    *) die "unknown product '$product'";;
  esac
}

# detect_arch <path-to-app-binary>
# Inspects the ELF and publishes the architecture under each packaging system's
# own naming scheme. This is what makes the script work unchanged if Google ever
# ships an arm64 build: feed it an arm64 tarball and you get arm64 packages.
#   AG_ARCH_RPM       rpm / ExclusiveArch token   (x86_64 | aarch64)
#   AG_ARCH_DEB       dpkg Architecture           (amd64  | arm64)
#   AG_ARCH_APPIMAGE  appimagetool ARCH           (x86_64 | aarch64)
detect_arch() {
  local bin="$1" desc
  desc=$(LC_ALL=C file -b "$bin" 2>/dev/null || true)
  case "$desc" in
    *x86-64*|*x86_64*)  AG_ARCH_RPM=x86_64;  AG_ARCH_DEB=amd64; AG_ARCH_APPIMAGE=x86_64 ;;
    *aarch64*|*ARM\ aarch64*) AG_ARCH_RPM=aarch64; AG_ARCH_DEB=arm64; AG_ARCH_APPIMAGE=aarch64 ;;
    *) die "unsupported binary architecture: $desc" ;;
  esac
}

# detect_version <staged-opt-dir>
# Reads the real product version out of the unpacked application tree.
#   - IDE   : resources/app/product.json -> "ideVersion"
#   - agent : resources/app.asar root package.json -> "version"
detect_version() {
  local appdir="$1" v
  case "$AG_PRODUCT" in
    ide)
      v=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["ideVersion"])' \
            "$appdir/resources/app/product.json") \
        || die "failed to read ideVersion from product.json"
      ;;
    agent)
      v=$(python3 "$LIB_DIR/asar.py" version "$appdir/resources/app.asar") \
        || die "failed to read version from app.asar"
      ;;
  esac
  [[ -n "$v" ]] || die "detected an empty version string"
  echo "$v"
}
