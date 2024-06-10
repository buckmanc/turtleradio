#!/usr/bin/env bash

#/etc/bluetooth/main.conf
#added experimental = true
#changed fast connect to true

# maybe do one path per day for performance, join them later?
gitRoot="$(git rev-parse --show-toplevel)"
logRootPath="$gitRoot/logs"
logPath="${logRootPath}/log.log"
logPathRaw="${logRootPath}/raw.log"
logPathPaired="${logRootPath}/paired.log"

mkdir -p "${logRootPath}"
touch "${logPath}"
touch "${logPathRaw}"
touch "${logPathPaired}"

bluetoothctl power on

echo "scanning..."
# figlist | while read -r line
stdbuf -oL bluetoothctl scan on | while read -r line
# bluetoothctl scan on | while read -r line
do
	if ! grep -iq "${line}" "${logPathRaw}"
	then
		echo "${line}"
		echo "${line}" >> "${logPathRaw}"
	fi

	if [ "${line}" == "Discovery started" ] || [[ "${line}" == *"] Controller "* ]]
	then
		continue
	fi

	# strip control chars
	line=$(echo "${line}" | ansi2txt | perl -pe 's/[\cA\cB]//g') 
	event=$(echo "${line}" | grep -Pio '^\[\w+?\] ' | perl -pe 's/[ \[\]]//g')
	logLine=$(echo "${line}" | perl -pe 's/^(\S+?) (\S+?) (\S+?) (.+)$/\2,\3/g')
	deviceName=$(echo "${line}" | perl -pe 's/^(\S+?) (\S+?) (\S+?) (.+)$/\4/g')
	macAddy=$(echo "${line}" | grep -Pio '\w\w:\w\w:\w\w:\w\w:\w\w:\w\w')


	bInfo=$(bluetoothctl info "${macAddy}")
	bName=$(echo "${bInfo}" | grep -Pio '(?<=name: ).+?(?=     |$)')
	bClass=$(echo "${bInfo}" | grep -Pio '(?<=class: ).+?(?=     |$)')
	bUUID=$(echo "${bInfo}" | grep -Pio '(?<=UUID: ).+?(?=     |$)')
	bIcon=$(echo "${bInfo}" | grep -Pio '(?<=Icon: ).+?(?=     |$)')
	# bIcon houses an enum-like device type
	# what to do when missing? Are missing items BLE devices/beacons?

	bPaired=$(echo "${bInfo}" | grep -Pio '(?<=Paired: ).+?(?=     |$)')
	bTrusted=$(echo "${bInfo}" | grep -Pio '(?<=Trusted: ).+?(?=     |$)')
	bConnected=$(echo "${bInfo}" | grep -Pio '(?<=Connected: ).+?(?=     |$)')

	# echo "macAddy: ${macAddy}"
	# echo "bInfo: ${bInfo}"

	# only accept device name from the "new" event of the main scan
	# otherwise, use the one nabbed from bluetoothctl info
	if [ "${event}" != "NEW" ]
	then
		deviceName="${bName}"
	fi

	logLine="${logLine},\"${deviceName}\",${bIcon},${bClass},\"${bUUID}"\"

	if ! grep -iq "${logLine}" "${logPath}" && [ -n "${deviceName}" ]
	then
		echo "${logLine}" | ts "%Y%m%d,%H%M%S," >> "${logPath}"
	fi

	# probable list of "icon" values that indicate audio output devices to pair with
	# audio-card
	# audio-headphones
	# audio-headset
	# multimedia-player

	# try only pairing on "new" event for now?
	# what about the pairing event?
	if [[ "${bIcon}" =~ ^(audio-.+|multimedia-player)$ ]] && [ "${event}" == "NEW" ]
	then
		echo "${deviceName} is an audio device!"

		if [ "${bPaired}" == "no" ]
		then
			bluetoothctl pair "${macAddy}"
		fi

		if [ "${bTrusted}" == "no" ]
		then
			bluetoothctl trust "${macAddy}" 
			# some users disconnect after trust
		fi

		if [ "${bConnected}" == "no" ]
		then
			bluetoothctl connect "${macAddy}" || bluetoothctl pair "${macAddy}"
		fi

		# play some audio!
		# aplay ~/Teenage\ Mutant\ Ninja\ Turtles\ Intro\ \(1987\)\ \[x4csk52\].mp3
	fi

done
