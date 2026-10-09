#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
developer_path="$(xcode-select -p)"
# Command Line Tools ship Swift Testing outside SwiftPM's default search path.
if [[ "$developer_path" == */CommandLineTools ]]; then
    swift test "$@" \
        -Xswiftc -F -Xswiftc "$developer_path/Library/Developer/Frameworks" \
        -Xlinker -rpath -Xlinker "$developer_path/Library/Developer/Frameworks" \
        -Xlinker -rpath -Xlinker "$developer_path/Library/Developer/usr/lib"
else
    swift test "$@"
fi
