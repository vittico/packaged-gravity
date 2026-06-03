# shellcheck shell=bash
#
# common.sh - logging, small helpers and tool detection shared by the build.
#
# This file is meant to be sourced, not executed. It assumes the caller has
# already set `set -euo pipefail`.

# --- Pretty logging --------------------------------------------------------
# Colours are only emitted when stderr is a terminal, so logs stay clean when
# redirected to a file or a CI system.
if [[ -t 2 ]]; then
  _C_BLUE=$'\033[34m'; _C_GREEN=$'\033[32m'; _C_YELLOW=$'\033[33m'
  _C_RED=$'\033[31m'; _C_BOLD=$'\033[1m'; _C_RESET=$'\033[0m'
else
  _C_BLUE=''; _C_GREEN=''; _C_YELLOW=''; _C_RED=''; _C_BOLD=''; _C_RESET=''
fi

log()   { printf '%s==>%s %s\n'  "$_C_BLUE$_C_BOLD" "$_C_RESET" "$*" >&2; }
info()  { printf '    %s\n' "$*" >&2; }
ok()    { printf '%s ok %s %s\n' "$_C_GREEN" "$_C_RESET" "$*" >&2; }
warn()  { printf '%swarn%s %s\n' "$_C_YELLOW" "$_C_RESET" "$*" >&2; }
die()   { printf '%serror%s %s\n' "$_C_RED$_C_BOLD" "$_C_RESET" "$*" >&2; exit 1; }

# have <cmd> -> true if the command exists on PATH.
have() { command -v "$1" >/dev/null 2>&1; }

# require <cmd> [hint] -> abort with a friendly message if a tool is missing.
require() {
  have "$1" && return 0
  die "required tool '$1' not found.${2:+ $2}"
}
