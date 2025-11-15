#!/usr/bin/env bash

# set -e

scriptDir="$(dirname "$0")"
gitRoot="$(git -C "$scriptDir" rev-parse --show-toplevel)"

# syncScriptsPath="$gitRoot/updates/sync-script-changes.sh"
loggerPath="$gitRoot/utilities/_log"
btAggPairPath="$gitRoot/utilities/bluetoothctl-aggressive-pair.sh"
setLedsPath="$gitRoot/utilities/set-leds.sh"
musicPathsPath="$gitRoot/utilities/music-paths.sh"
aplayPath="$gitRoot/utilities/aplay_turtleradio.sh"

# "$syncScriptsPath"

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

setLeds() {
		"$setLedsPath" "$@"
}

shutdown() {
	setLeds
	exit 0
}

ytUpdated=0
ytUpdate() {
	if [[ "$ytUpdated" == 0 ]]
	then
		"$gitRoot/utilities/yt-dlp-update"
		ytUpdated=1
	fi
}

# turn off leds when this script is ended
trap shutdown SIGINT

# setLeds test

source "$musicPathsPath"

mkdir -p "$musicDir"
mkdir -p "$rareMusicDir"
mkdir -p "$interstitialsDir"

dl()
{
	ytUpdate

	url="$1"
	destDir="$2"
	destName="$3"

	shift 3 || true

	tempPath="/tmp/$destName"
	rm -f "$tempPath"
	# TODO add playlist support
	if [[ "$url" == *youtu*  || "$url" == *dailymotion* ]]
	then
		yt-dlp -q -x --audio-quality 0 "$url" --audio-format wav --output "$tempPath"
	else
		curl --disable --silent -L "$url" -o "$tempPath"
	fi

	# if any other args are provided, pass them to ffmpeg
	if [[ $# -gt 0 ]]
	then
		tempFfmpegPath="/tmp/ffmpeg-dl.wav"
		rm -f "$tempFfmpegPath"
		mv "$tempPath" "$tempFfmpegPath"
		ffmpeg -hide_banner -loglevel error -i "$tempFfmpegPath" $@ -c copy "$tempPath"
	fi

	# normalize audio
	# ebu normalization is the default
	# assuming we're using the right settings, -14 is what spotify uses
	ffmpeg-normalize "$tempPath" -o "$destDir/$destName" -ext wav --target-level -14
}

if [[ -z "$(getMusic)" ]]
then
	echo "downloading default music..."
	dl https://www.dailymotion.com/video/x4csk52 "$musicDir" "tmnt_theme_1987.wav"
fi

if [[ -z "$(getRareMusic)" ]]
then
	echo "downloading default rare music..."
	dl https://m.youtube.com/watch?v=04V0HhJatoc "$rareMusicDir" "tmnt_theme_by_horse_the_band.wav" -ss 0:22.2
	dl https://m.youtube.com/watch?v=3HjqVZp-xeI "$rareMusicDir" "tmnt_theme_out_of_the_shadows_2016.wav"
	dl https://m.youtube.com/watch?v=OAxZo9DSXjI "$rareMusicDir" "tmnt_theme_by_mike_patton_2022.wav"
fi

if [[ -z "$(getInterstitials)" ]]
then
	echo "downloading default interstitials..."
	dl https://www.myinstants.com/media/sounds/cowabunga-tmnt.mp3 "$interstitialsDir" "cowabunga.wav"
	# TODO add a yt playlist of default interstitials
	# dl "$(echo "$sneakyurl" | base64 -d)" "$interstitialsDir"
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
		setLeds red
		# initial play log here in case of errors or device turning off during playback
		"$loggerPath" "bluetooth-play" "beginning playback on $macAddy $logDeviceName" --all

		"$aplayPath" "$macAddy"
	
		playTime="$(stopwatch_stop)"
		setLeds green
		logDeviceName="$deviceName"

		if [[ -z "$logDeviceName" ]]
		then
			logDeviceName="$macAddy"
		fi

		"$loggerPath" "bluetooth-play" "played on $macAddy $logDeviceName for $playTime" --all

		bluetoothctl remove "$macAddy"
	fi

done

