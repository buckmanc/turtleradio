#!/usr/bin/env bash

set -e

scriptDir="$(dirname "$0")"
gitRoot="$(git -C "$scriptDir" rev-parse --show-toplevel)"

cd "$gitRoot/.assets"

convert pi_full.png -background none -trim -resize '512x' -gravity center -extent '^731x' -gravity west -extent '^931x' pi.png
convert mikeradio_full.jpg -resize '512x' mikeradio.png
