#!/usr/bin/env bash

gitRoot="$(git rev-parse --show-toplevel)"

musicDir="$gitRoot/music"
rareMusicDir="$gitRoot/music_rare"
interstitialsDir="$gitRoot/interstitials"

stopwatch_start(){
	if [[ -z "$startTime" ]]
	then
		startTime="$(date +%s)"
	fi
}

stopwatch_stop(){
	endTime="$(date +%s)"
	elapsedSeconds=$((endTime - startTime))
	startTime=''

	# minutes=$((elapsedSeconds / 60))
	# seconds=$((elapsedSeconds % 60))
	minutes="$(echo "$elapsedSeconds / 60" | bc -l)"

	echo "$minutes minutes"
}

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
mkdir -p "$rareMusicDir"
mkdir -p "$interstitialsDir"

getFile()
{
	dir="$1"
	find "$dir" -type f -iname '*.wav' | shuf -n 1
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

dl()
{
	url="$1"
	destDir="$2"
	destName="$3"

	yt-dlp -x --audio-quality 0 "$url" --audio-format wav --paths "$destDir" --output "$destName"
}

if [[ -z "$(getMusic)" ]]
then
	dl https://www.dailymotion.com/video/x4csk52 "$musicDir" "tmnt_theme_1987.wav"
fi

if [[ -z "$(getRareMusic)" ]]
then
	# TODO normalize volume on downloaded files
	dl https://m.youtube.com/watch?v=04V0HhJatoc "$rareMusicDir" "tmnt_theme_by_horse_the_band.wav"
	ffmpeg -i "$rareMusicDir/tmnt_theme_by_horse_the_band.wav" -ss 0:22 -c copy "/tmp/tmnt.wav"
	mv "/tmp/tmnt.wav" "$rareMusicDir/tmnt_theme_by_horse_the_band.wav"
	dl https://m.youtube.com/watch?v=3HjqVZp-xeI "$rareMusicDir" "tmnt_theme_out_of_the_shadows_2016.wav"
	dl https://m.youtube.com/watch?v=OAxZo9DSXjI "$rareMusicDir" "tmnt_theme_by_mike_patton_2022.wav"
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

		stopwatch_start

		loopCount=0
		lastPlayedRare=0

		# play some audio!
		while true
		do
			loopCount=$((loopCount+1))
			if [[ "$loopCount" -gt 2 && "$lastPlayedRare" == 0 && "$(shuf -n 1 -i 1-3)" == 1 ]]
			then
				musicPath="$(getRareMusic)"
				lastPlayedRare=1
			else
				musicPath="$(getMusic)"
				lastPlayedRare=0
			fi

			interstitialPath="$(getInterstitials)"

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

		playTime="$(stopwatch_stop)"
		logDeviceName="$deviceName"

		if [[ -z "$logDeviceName" ]]
		then
			logDeviceName="$macAddy"
		fi

		"$loggerPath" "bluetooth-play" "played on $logDeviceName for $playTime" --all

		bluetoothctl remove "$macAddy"
	fi

done

