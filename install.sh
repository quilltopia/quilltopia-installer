#!/bin/sh
set -eu

REPOSITORY=quilltopia/quilltopia
VERSION=v0.0.4
ARCHIVE=quilltopia-aarch64-apple-darwin.tar.gz

fail() {
  printf 'quilltopia-installer: %s\n' "$*" >&2
  exit 1
}

usage() {
  printf '%s\n' \
    'Usage: install.sh [--force] [--install-root PATH]' \
    'Download and install quilltopia v0.0.4 for Apple Silicon macOS 26+.'
}

# Validate without consuming the arguments forwarded to the archive installer.
validate_arguments() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --force) shift ;;
      --install-root)
        [ "$#" -ge 2 ] && [ -n "$2" ] || fail '--install-root needs a path'
        shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) fail "unknown option: $1" ;;
    esac
  done
}

validate_arguments "$@"
for required_command in gh tar shasum mktemp uname sw_vers sed; do
  command -v "$required_command" >/dev/null 2>&1 \
    || fail "$required_command not found on PATH"
done
[ "$(uname -s)" = Darwin ] || fail 'macOS is required'
[ "$(uname -m)" = arm64 ] || fail 'Apple Silicon is required'
macos_major=$(sw_vers -productVersion | sed 's/\..*//')
[ "$macos_major" -ge 26 ] || fail 'macOS 26 or newer is required'

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/quilltopia-installer.XXXXXX")
keep_suite=0
cleanup() {
  if [ "$keep_suite" -eq 1 ]; then
    printf 'Installation did not complete; suite retained at: %s/quilltopia\n' "$work_dir" >&2
  else
    rm -rf -- "$work_dir"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

printf 'Downloading quilltopia %s from %s…\n' "$VERSION" "$REPOSITORY"
gh release download "$VERSION" --repo "$REPOSITORY" \
  --pattern "$ARCHIVE" --pattern "$ARCHIVE.sha256" --dir "$work_dir"

printf 'Verifying SHA-256…\n'
(
  cd "$work_dir"
  shasum -a 256 -c "$ARCHIVE.sha256"
)
tar -xzf "$work_dir/$ARCHIVE" -C "$work_dir"
[ -f "$work_dir/quilltopia/install.sh" ] || fail 'archive lacks quilltopia/install.sh'

# Preserve the independent recovery binary if installation fails or is interrupted.
keep_suite=1
printf 'Running the archive installer…\n'
/bin/sh "$work_dir/quilltopia/install.sh" "$@"
keep_suite=0
