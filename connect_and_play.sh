#!/usr/bin/env bash

gitRoot="$(git rev-parse --show-toplevel)"

musicDir="$gitRoot/music"
interstitialsDir="$gitRoot/interstitials"

# sync script changes if the home path version exists

loggerPath="$gitRoot/_log"
loggerPathHome="$HOME/bin/_log"
if [[ -x "$loggerPathHome" ]]
then
	rsync -hau "$loggerPathHome" "$loggerPath"
	rsync -hau "$loggerPath" "$loggerPathHome"
fi

btAggPairPath="$gitRoot/bluetoothctl-aggressive-pair.sh"
btAggPairPathHome="$HOME/bin/bluetoothctl-aggressive-pair"
if [[ -x "$btAggPairPathHome" ]]
then
	rsync -hau "$btAggPairPathHome" "$btAggPairPath"
	rsync -hau "$btAggPairPath" "$btAggPairPathHome"
fi

mkdir -p "$musicDir"
mkdir -p "$interstitialsDir"

getMusic()
{
	find "$musicDir" -type f -iname '*.wav'
}
getInterstitials()
{
	find "$interstitialsDir" -type f -iname '*.wav'
}

if [[ -z "$(getMusic)" ]]
then
	yt-dlp -x --audio-quality 0 https://www.dailymotion.com/video/x4csk52 --audio-format wav --paths "$musicDir" --output "tmnt.wav"
fi

macAddyRegex='([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})'

bluetoothctl system-alias "Turtle Radio"

while true
do

	pairedDevices="$(bluetoothctl devices | grep -iPo "$macAddyRegex")"
	if [[ -n "$pairedDevices" ]]
	then
		echo "unpairing $(echo "$pairedDevices" | wc -l) devices..."
	fi
	echo "$pairedDevices" | while read -r device
	do
		bluetoothctl remove "$device"
	done

	# using source so that the macAddy var is available here
	source "$btAggPairPath" --loop

	if [[ -n "$macAddy" ]]
	then

		# TODO record how long audio played
		# play some audio!
		while true
		do
			musicPath="$(getMusic | shuf -n 1)"
			interstitialPath="$(getInterstitials | shuf -n 1)"
			if ! aplay -D "bluealsa:DEV=$macAddy,PROFILE=a2dp" "$musicPath"
			then
				break
			fi

			if [[ -n "$interstitialPath" ]]
			then
				if ! aplay -D "bluealsa:DEV=$macAddy,PROFILE=a2dp" "$interstitialPath"
				then
					break
				fi
			fi

		done

		bluetoothctl remove "$macAddy"
	fi

done

