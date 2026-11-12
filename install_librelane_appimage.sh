#!/usr/bin/env bash
# Run from Ubuntu Bash in WSL2 as your regular Linux user.
set -euo pipefail

if (( EUID == 0 )); then
    printf 'Run as your regular user. Use sudo only for apt.\n' >&2
    exit 1
fi

version=3.0.16
arch=$(uname -m)
case "$arch" in
    x86_64|aarch64) ;;
    *) printf 'Unsupported architecture: %s\n' "$arch" >&2; exit 1 ;;
esac

if ! command -v curl >/dev/null; then
    printf 'Install curl first: sudo apt update && sudo apt install curl ca-certificates\n' >&2
    exit 1
fi

asset="librelane-devshell-${arch}.AppImage"
install_dir="$HOME/eda/librelane-appimage/$version"
app="$install_dir/$asset"
url="https://github.com/librelane/librelane/releases/download/$version/$asset"
mkdir -p -- "$install_dir"

if [[ ! -s "$app" ]]; then
    temp=$(mktemp "$install_dir/.download.XXXXXXXX")
    trap 'rm -f -- "$temp"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    printf 'Downloading LibreLane %s (%s)\n' "$version" "$arch"
    curl --fail --location --retry 3 --output "$temp" "$url"
    # AppImage Type 2 starts with ELF and has AI followed by 0x02 at offset 8.
    if [[ $(od -An -tx1 -N4 "$temp" | tr -d '[:space:]') != 7f454c46 ||
          $(od -An -tx1 -j8 -N3 "$temp" | tr -d '[:space:]') != 414902 ]]; then
        printf 'The download does not have a Type 2 AppImage header.\n' >&2
        exit 1
    fi
    chmod u+x -- "$temp"
    mv -- "$temp" "$app"
else
    printf 'Using existing file: %s\n' "$app"
fi

chmod u+x -- "$app"
printf '\nOpen LibreLane: %q\n' "$app"
printf 'Inside the AppImage shell, run:\n  librelane --version\n  librelane --smoke-test\n'
printf '\nIf FUSE mounting fails, try: %q --appimage-extract-and-run\n' "$app"
