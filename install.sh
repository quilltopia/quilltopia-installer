#!/bin/sh
set -eu

REPOSITORY=quilltopia/quilltopia
ARCHIVE=quilltopia-aarch64-apple-darwin.tar.gz

fail() {
  printf 'quilltopia-installer: %s\n' "$*" >&2
  exit 1
}

usage() {
  printf '%s\n' \
    'Usage: install.sh [--version TAG] [--force] [--install-root PATH] [--remove-quarantine]' \
    'Install the latest stable release or an exact --version TAG for Apple Silicon macOS 26+.'
}

VERSION=
install_force=0
remove_quarantine=0
has_install_root=0
install_root=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      [ "$#" -ge 2 ] && [ -n "$2" ] || fail '--version needs a release tag'
      case "$2" in -*) fail '--version needs a release tag, not an option' ;; esac
      VERSION=$2
      shift 2 ;;
    --force) install_force=1; shift ;;
    --remove-quarantine) remove_quarantine=1; shift ;;
    --install-root)
      [ "$#" -ge 2 ] && [ -n "$2" ] || fail '--install-root needs a path'
      install_root=$2
      has_install_root=1
      shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

# Only the archive installer's own arguments are forwarded.
set --
if [ "$install_force" -eq 1 ]; then
  set -- "$@" --force
fi
if [ "$has_install_root" -eq 1 ]; then
  set -- "$@" --install-root "$install_root"
fi
for required_command in gh tar shasum mktemp uname sw_vers sed; do
  command -v "$required_command" >/dev/null 2>&1 \
    || fail "$required_command not found on PATH"
done
if [ "$remove_quarantine" -eq 1 ]; then
  command -v xattr >/dev/null 2>&1 || fail 'xattr not found on PATH'
fi
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

# Resolve latest once; an explicit tag is downloaded exactly, with no fallback.
if [ -z "$VERSION" ]; then
  VERSION=$(gh release view --repo "$REPOSITORY" --json tagName --jq '.tagName')
  [ -n "$VERSION" ] || fail 'latest stable release has no tag'
fi
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
if [ "$remove_quarantine" -eq 1 ]; then
  printf 'Removing com.apple.quarantine from the verified suite…\n'
  xattr -r -d com.apple.quarantine "$work_dir/quilltopia" \
    || fail 'could not remove quarantine; installation stopped'
fi
printf 'Running the archive installer…\n'
/bin/sh "$work_dir/quilltopia/install.sh" "$@"
keep_suite=0
