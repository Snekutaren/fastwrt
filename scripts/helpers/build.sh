#!/bin/bash

set -e  # stop if any command fails
set -u  # error if using unset variables

PROFILE="glinet_gl-mt6000"
PACKAGELIST="packagelist.txt"

if [[ ! -f "$PACKAGELIST" ]]; then
  echo "Error: '$PACKAGELIST' not found!"
  exit 1
fi

PACKAGES="$(grep -vE '^\s*#|^\s*$' "$PACKAGELIST" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '\n' ' ')"

make image PROFILE="$PROFILE" PACKAGES="$PACKAGES" V=s
