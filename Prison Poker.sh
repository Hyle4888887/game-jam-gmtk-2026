#!/bin/sh
printf '\033c\033]0;%s\a' Prison Poker
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Prison Poker.x86_64" "$@"
