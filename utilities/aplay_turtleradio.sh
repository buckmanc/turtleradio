#!/usr/bin/env bash

scriptDir="$(dirname "$0")"
gitRoot="$(git -C "$scriptDir" rev-parse --show-toplevel)"

source "$gitRoot/utilities/music-paths.sh"

optMacAddress=''
optBoth=0
for arg in "$@"
do
	if [[ "$arg" == "-b" || "$arg" == "--both" ]]
	then
		optBoth=1
	else
		# could validate this, probably not worth the trouble
		optMacAddress="$arg"
	fi
done

# aplay wrapper for playing on bt, audio jack, or both
yayplay(){

	audioPath="$1"
	fileName="$(basename "$audioPath")"
	interrupted=0

	# TODO cleaner output
	echo "PLAYING: $fileName"

	# run a background aplay if we're doing both
	if [[ -n "$optMacAddress" && "$optBoth" == 1 ]]
	then
		aplay "$musicPath" > /dev/null &
	fi

	# primary output
	if [[ -n "$optMacAddress" ]]
	then
		if ! aplay -D "bluealsa:DEV=$optMacAddress,PROFILE=a2dp" "$audioPath" > /dev/null
		then
			interrupted=1
		fi
	else
		if ! aplay "$musicPath" > /dev/null 2>&1
		then
			interrupted=1
		fi
	fi

	# kill the bg aplay session we started earlier
	if [[ -n "$optMacAddress" && "$optBoth" == 1 ]]
	then
		# could kill unrelated aplay instances
		# but practically should be just fine
		pkill aplay
	fi

	return $interrupted
}

loopCount=0
lastPlayedRare=0

# play some audio!
while true
do
	loopCount=$((loopCount+1))
	if [[ "$loopCount" -gt 2 && "$lastPlayedRare" == 0 && "$(shuf -n 1 -i 1-3 --random-source='/dev/urandom')" == 1 ]]
	then
		musicPath="$(getRareMusic)"
		lastPlayedRare=1
	else
		musicPath="$(getMusic)"
		lastPlayedRare=0
	fi

	interstitialPath="$(getInterstitials)"

	if ! yayplay "$musicPath"
	then
		break
	fi

	if [[ -n "$interstitialPath" ]]
	then
		if ! yayplay "$interstitialPath"
		then
			break
		fi
	fi

done
