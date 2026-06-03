#!/usr/bin/env bash
#
# build.sh - build native Linux packages (.rpm and/or .deb) from an official
# Antigravity Linux release tarball (the IDE or the coding agent).
#
# The product (agent vs IDE) and its version are detected automatically, so the
# usual invocation is simply:
#
#     ./build.sh "Antigravity IDE.tar.gz"
#     ./build.sh Antigravity.tar.gz --format rpm
#
# See ./build.sh --help and README.md for details.

set -euo pipefail

# Resolve our own location so the script works from any working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# shellcheck source=lib/common.sh
source "$LIB_DIR/common.sh"
# shellcheck source=lib/detect.sh
source "$LIB_DIR/detect.sh"
# shellcheck source=lib/stage.sh
source "$LIB_DIR/stage.sh"
# shellcheck source=lib/rpm.sh
source "$LIB_DIR/rpm.sh"
# shellcheck source=lib/deb.sh
source "$LIB_DIR/deb.sh"
# shellcheck source=lib/appimage.sh
source "$LIB_DIR/appimage.sh"
# shellcheck source=lib/flatpak.sh
source "$LIB_DIR/flatpak.sh"

usage() {
  cat <<'EOF'
Usage: ./build.sh [options] <tarball>

Build native Linux packages from an Antigravity release tarball.

Options:
  -f, --format <fmt>    rpm | deb | appimage | flatpak | all
                        (default: native = rpm + deb)  may be comma-separated
  -o, --outdir <dir>    output directory  (default: ./dist)
      --product <p>     force agent | ide (default: auto-detect)
      --version <v>     override the detected version
  -k, --keep            keep the temporary build tree (for debugging)
  -h, --help            show this help

Formats:
  rpm       Fedora/RHEL/openSUSE package          (needs rpmbuild)
  deb       Debian/Ubuntu package                 (needs dpkg-deb)
  appimage  portable single-file app              (fetches appimagetool)
  flatpak   sandboxed bundle  [EXPERIMENTAL]      (needs flatpak-builder)
  all       rpm + deb + appimage
  native    rpm + deb        (the default)

Examples:
  ./build.sh "Antigravity IDE.tar.gz"
  ./build.sh Antigravity.tar.gz --format rpm
  ./build.sh Antigravity.tar.gz -f deb,appimage -o /tmp/out
  ./build.sh Antigravity.tar.gz -f all
EOF
}

# --- Argument parsing ------------------------------------------------------
FORMAT="native"
OUTDIR="$PWD/dist"
FORCE_PRODUCT=""
FORCE_VERSION=""
KEEP=0
TARBALL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--format)  FORMAT="${2:-}"; shift 2;;
    -o|--outdir)  OUTDIR="${2:-}"; shift 2;;
    --product)    FORCE_PRODUCT="${2:-}"; shift 2;;
    --version)    FORCE_VERSION="${2:-}"; shift 2;;
    -k|--keep)    KEEP=1; shift;;
    -h|--help)    usage; exit 0;;
    -*)           die "unknown option: $1 (try --help)";;
    *)
      [[ -z "$TARBALL" ]] || die "unexpected extra argument: $1"
      TARBALL="$1"; shift;;
  esac
done

[[ -n "$TARBALL" ]] || { usage; exit 1; }
[[ -f "$TARBALL" ]] || die "tarball not found: $TARBALL"
TARBALL="$(cd "$(dirname "$TARBALL")" && pwd)/$(basename "$TARBALL")"  # absolutise

# Expand the (possibly comma-separated) --format into a deduplicated list of
# concrete builders. "all" and "native" are convenience aliases.
expand_formats() {
  local raw="$1" out=() tok
  IFS=',' read -r -a _toks <<< "$raw"
  for tok in "${_toks[@]}"; do
    case "$tok" in
      all)      out+=(rpm deb appimage);;
      native)   out+=(rpm deb);;
      rpm|deb|appimage|flatpak) out+=("$tok");;
      "") ;;
      *) die "invalid --format token '$tok' (expected rpm, deb, appimage, flatpak, all or native)";;
    esac
  done
  # Deduplicate while preserving order.
  printf '%s\n' "${out[@]}" | awk '!seen[$0]++'
}
mapfile -t FORMATS < <(expand_formats "$FORMAT")
[[ ${#FORMATS[@]} -gt 0 ]] || die "no package formats selected"

# --- Preconditions ---------------------------------------------------------
require python3 "Needed to read versions and unpack the agent's app.asar."
require tar

# --- Temporary workspace ---------------------------------------------------
WORK="$(mktemp -d "${TMPDIR:-/tmp}/antigravity-pkg.XXXXXX")"
cleanup() { [[ "$KEEP" -eq 1 ]] || rm -rf "$WORK"; }
trap cleanup EXIT
[[ "$KEEP" -eq 1 ]] && info "Keeping work dir: $WORK"

# --- Detect product & version ---------------------------------------------
log "Inspecting $(basename "$TARBALL")"
LISTING="$WORK/listing.txt"
tar -tzf "$TARBALL" > "$LISTING"

TOPDIR="$(head -1 "$LISTING" | cut -d/ -f1)"
PRODUCT="${FORCE_PRODUCT:-$(detect_product "$LISTING")}"
configure_product "$PRODUCT" "$TOPDIR"

# --- Stage the install tree (unpacks the app and detects its version) ------
build_stage "$TARBALL"

# --- Build the requested formats ------------------------------------------
for fmt in "${FORMATS[@]}"; do
  case "$fmt" in
    rpm)      build_rpm "$OUTDIR";;
    deb)      build_deb "$OUTDIR";;
    appimage) build_appimage "$OUTDIR";;
    flatpak)  build_flatpak "$OUTDIR";;
  esac
done

log "Done. Packages are in: $OUTDIR"
