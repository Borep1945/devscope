#!/bin/zsh
set -eu
print "Workspace health"
print "Working directory: $PWD"
/usr/bin/git --version
/usr/bin/swift --version
/usr/bin/df -h .
