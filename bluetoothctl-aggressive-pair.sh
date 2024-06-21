#!/usr/bin/env bash

#/etc/bluetooth/main.conf
#added experimental = true
#changed fast connect to true

# maybe do one path per day for performance, join them later?
gitRoot="$(git rev-parse --show-toplevel)"
logRootPath="$gitRoot/logs"
logPath="$logRootPath/log.log"
logPathRaw="$logRootPath/raw.log"
logPathPaired="$logRootPath/paired.log"
logPathConnectAttempts="$logRootPath/connect_attempts.log"
exclusionsPath="$gitRoot/exclusions.config"

mkdir -p "$logRootPath"
touch -a "$logPath"
touch -a "$logPathRaw"
touch -a "$logPathPaired"
touch -a "$logPathConnectAttempts"
touch -a "$exclusionsPath"

bluetoothctl power on

while true
do

	echo "scanning..."
	# bluetoothctl scan on | while read -r line
	# stdbuf -oL bluetoothctl scan on | while read -r line
	while read -r line
	do
		if ! grep -iq "$line" "$logPathRaw"
		then
			echo "$line"
			echo "$line" >> "$logPathRaw"
		fi

		if [ "$line" == "Discovery started" ] || [[ "$line" == *"] Controller "* ]]
		then
			continue
		fi

		# strip control chars
		line=$(echo "$line" | ansi2txt | perl -pe 's/[\cA\cB]//g') 
		event=$(echo "$line" | grep -Pio '^\[\w+?\] ' | perl -pe 's/[ \[\]]//g')
		logLine=$(echo "$line" | perl -pe 's/^(\S+?) (\S+?) (\S+?) (.+)$/\2,\3/g')
		deviceName=$(echo "$line" | perl -pe 's/^(\S+?) (\S+?) (\S+?) (.+)$/\4/g')
		macAddy=$(echo "$line" | grep -Pio '\w\w:\w\w:\w\w:\w\w:\w\w:\w\w')


		bInfo=$(bluetoothctl info "$macAddy")
		bName=$(echo "$bInfo" | grep -Pio '(?<=name: ).+?(?=     |$)')
		bClass=$(echo "$bInfo" | grep -Pio '(?<=class: ).+?(?=     |$)')
		bUUID=$(echo "$bInfo" | grep -Pio '(?<=UUID: ).+?(?=     |$)')
		bIcon=$(echo "$bInfo" | grep -Pio '(?<=Icon: ).+?(?=     |$)')
		# bIcon houses an enum-like device type
		# what to do when missing? Are missing items BLE devices/beacons?

		bPaired=$(echo "$bInfo" | grep -Pio '(?<=Paired: ).+?(?=     |$)')
		bTrusted=$(echo "$bInfo" | grep -Pio '(?<=Trusted: ).+?(?=     |$)')
		bConnected=$(echo "$bInfo" | grep -Pio '(?<=Connected: ).+?(?=     |$)')

		# echo "macAddy: $macAddy"
		# echo "bInfo: $bInfo"

		# use the name from bluetoothctl info if present
		if [[ -n "$bName" ]]
		then
			deviceName="$bName"
		fi

		logLine="$logLine,\"$deviceName\",$bIcon,$bClass,\"$bUUID"\"

		if ! grep -Fiq "$logLine" "$logPath" && [[ -n "$deviceName" ]]
		then
			echo "$logLine" | ts "%F,%R," >> "$logPath"
		fi

		# could make this a wildcard match, but direct mac addy is probably better
		if grep -iq "$macAddy" "$exclusionsPath"
		then
			echo "$deviceName is excluded, skipping"
			continue
		fi

		borkedLogPath="$logRootPath/borked_$(date +%F_%H).log"
		if [[ -f "$borkedLogPath" ]]
		then
			borkedCount="$(grep -Fic "$macAddy" "$borkedLogPath")"
			if [[ "$borkedCount" -ge 4 ]]
			then
				echo "$deviceName has failed to connect repeatedly recently, skipping"
				continue
			fi
		fi

		loggerPath="$HOME/bin/_log"
		if [[ -x "$loggerPath" ]] && echo "$deviceName" | grep -Piqv '(rssi|txpower): '
		then
			"$loggerPath" "bluetooth" "\"$deviceName\",$macAddy" > /dev/null
		fi

		# probable list of "icon" values that indicate audio output devices to pair with
		# audio-card
		# audio-headphones
		# audio-headset
		# multimedia-player

		# try only pairing on "new" event for now?
		# what about the pairing event?
		if [[ "$bIcon" =~ ^(audio-.+|multimedia-player)$ ]] && [ "$event" == "NEW" ]
		then
			echo "$deviceName is an audio device!"
			break
		fi

	done < <( stdbuf -oL bluetoothctl scan on )

	connectError=0

	if [[ "$bPaired" == "no" && "$connectError" == "0" ]]
	then
		echo "pairing..."
		if ! msg="$(bluetoothctl pair "$macAddy" 2>&1)"
		then
			connectError=1
		fi

		echo "$msg"	| ts "%F,%R," | tee -a "$logPathConnectAttempts"
	fi

	if [[ "$bTrusted" == "no" && "$connectError" == "0" ]]
	then
		echo "trusting..."
		if ! msg="$(bluetoothctl trust "$macAddy" 2>&1)"
		then
			connectError=1
		fi

		echo "$msg"	| ts "%F,%R," | tee -a "$logPathConnectAttempts"
	fi

	if [[ "$bConnected" == "no" && "$connectError" == "0" ]]
	then
		echo "connecting..."
		if ! msg="$(bluetoothctl connect "$macAddy" 2>&1)"
		then
			connectError=1
		fi

		echo "$msg"	| ts "%F,%R," | tee -a "$logPathConnectAttempts"
	fi

	# if there are no errors from trying to connect
	# break out of the loop
	# otherwise, loop back and restart scanning
	if [[ "$connectError" == "0" ]]
	then
		break
	else
		echo "$macAddy" >> "$borkedLogPath"
	fi

done

# TODO better checking for if we're successfully paired

echo "$logLine" | ts "%F,%R," >> "$logPathPaired"
