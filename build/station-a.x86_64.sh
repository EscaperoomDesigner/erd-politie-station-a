#!/bin/sh
printf '\033c\033]0;%s\a' politietrailer-cognitiespel
base_path="$(dirname "$(realpath "$0")")"
"$base_path/station-a.x86_64.arm64" "$@"
