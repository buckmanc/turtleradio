#!/usr/bin/env bash

scriptDir="$(dirname "$0")"
gitRoot="$(git -C "$scriptDir" rev-parse --show-toplevel)"

musicDir="$gitRoot/music"
rareMusicDir="$gitRoot/music_rare"
interstitialsDir="$gitRoot/interstitials"

getFile()
{
	dir="$1"
	find "$dir" -type f -iname '*.wav' | shuf -n 1 --random-source='/dev/urandom'
}

getMusic()
{
	getFile "$musicDir"
}

getRareMusic()
{
	getFile "$rareMusicDir"
}

getInterstitials()
{
	getFile "$interstitialsDir"
}
