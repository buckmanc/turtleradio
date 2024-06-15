#!/usr/bin/env bash

gitRoot="$(git rev-parse --show-toplevel)"

musicDir="$gitRoot/music"
interstitialsDir="$gitRoot/interstitials"

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

bluetoothctl system-alias "Turtle Radio"

while true
do

	# using source so that the macAddy var is available here
	source "$gitRoot/bluetoothctl-aggressive-pair.sh"

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

done

