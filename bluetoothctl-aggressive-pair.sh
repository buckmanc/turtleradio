#!/usr/bin/env bash

#/etc/bluetooth/main.conf
#added experimental = true
#changed fast connect to true

gitRoot="$(git rev-parse --show-toplevel)"

# sync exclusions in the local dir and in the .config folder
exclusionsPath="$gitRoot/bt_exclusions.config"
exclusionsPathHome="$HOME/.config/bt_exclusions.config"
if [[ -x "$exclusionsPathHome" ]]
then
	rsync -hau "$exclusionsPathHome" "$exclusionsPath"
	rsync -hau "$exclusionsPath" "$exclusionsPathHome"
fi
logPathConnectAttemptsDir="$HOME/.logs/bluetooth_connect_attempts/"
mkdir -p "$logPathConnectAttemptsDir"

# use the logger next to this script
loggerPath="$(dirname "$0")/_log"

optLogOnly=0
optLoop=0
optAllDeets=0
newRecords=0

for arg in "$@"
do
	if [[ "$arg" == "-l" || "$arg" == "--loop" ]]
	then
		optLoop=1
	elif [[ "$arg" == "-a" || "$arg" == "--all" ]]
	then
		optAllDeets=1
	elif [[ "$arg" == "--log-only" ]]
	then
		optLogOnly=1
	fi
done

if [[ "$optLoop" == "0" ]]
then
	timeoutTime=30
else
	timeoutTime=99999
fi

touch -a "$exclusionsPath"

bluetoothctl power on

while true
do

	echo "scanning..."
	# bluetoothctl scan on | while read -r line
	# stdbuf -oL bluetoothctl scan on | while read -r line
	while read -r line
	do
		if [[ "$optAllDeets" == "1" ]]
		then
			echo "$line"
		fi

		if [[ "$line" == "Discovery started" ]] || [[ "$line" == *"] Controller "* ]]
		then
			continue
		fi

		macAddyRegex='([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})'

		# strip control chars
		line=$(echo "$line" | ansi2txt | perl -pe 's/[\cA\cB]//g') 
		event=$(echo "$line" | grep -Pio '^\[\w+?\] ' | perl -pe 's/[ \[\]]//g')
		logLine=$(echo "$line" | perl -pe 's/^(\S+?) (\S+?) (\S+?) (.+)$/\2,\3/g')
		deviceName=$(echo "$line" | perl -pe 's/^(\S+?) (\S+?) (\S+?) (.+)$/\4/g')
		macAddy=$(echo "$line" | grep -Pio "$macAddyRegex" | head -n 1)

		# if mac addy is blank then we got something other than what we wanted
		if [[ -z "$macAddy" ]]
		then
			continue
		fi


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

		# clean up valid names
		deviceName="$(echo "$deviceName" | perl -pe 's/^(name|alias): ?//g')"

		logLine="$logLine,\"$deviceName\",$bIcon,$bClass,\"$bUUID"\"

		if echo "$deviceName" | grep -Piq '^"?(rssi|txpower|manufacturerdata\.key|manufacturerdata\.value|uuids): ' || echo "$deviceName" | grep -Piq "$macAddyRegex"
		then
			deviceName=''
		fi

		# primary log
		logResult="$("$loggerPath" "bluetooth" "\"$deviceName\",$macAddy")"

		if [[ "$optLogOnly" == "1" ]]
		then
			if [[ "$optAllDeets" == "0" ]]
			then
				# eat nopers message, prefer to display at end
				if ! echo "$logResult" | grep -Piq "^no new"
				then
					echo "$logResult"
				fi
			fi

			if ! echo "$logResult" | grep -Piq "^no new"
			then
				newRecords=1
			fi

			continue
		fi


		# could make this a wildcard match, but direct mac addy is probably better
		if grep -iq "$macAddy" "$exclusionsPath"
		then
			echo "$deviceName is excluded, skipping"
			continue
		fi

		logPathConnectAttempts="$logPathConnectAttemptsDir/$HOSTNAME_$(date +%F_%H).log"
		if [[ -f "$logPathConnectAttempts" ]]
		then
			attemptCount="$(grep -Fic "$macAddy" "$logPathConnectAttempts")"
			if [[ "$attemptCount" -ge 3 ]]
			then
				echo "$deviceName has been attempted $attemptCount times. Skipping"
				continue
			fi
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

	# timeout option is required for non interactive scanning
	done < <( stdbuf -oL bluetoothctl --timeout "$timeoutTime" scan on )

	# report and back out here if logging only
	if [[ "$optLogOnly" == "1" ]]
	then
		if [[ "$optLogOnly" == "1" && "$newRecords" == "0" && "$optLoop" == "0" ]]
		then
			echo "no new devices logged"
		fi

		exit
	fi

	connectError=0
	echo "$macAddy" >> "$logPathConnectAttempts"

	if [[ "$bPaired" == "no" && "$connectError" == "0" ]]
	then
		echo "pairing..."
		if ! msg="$(bluetoothctl pair "$macAddy" 2>&1)"
		then
			connectError=1
		fi

		echo "$msg"
	fi

	if [[ "$bTrusted" == "no" && "$connectError" == "0" ]]
	then
		echo "trusting..."
		if ! msg="$(bluetoothctl trust "$macAddy" 2>&1)"
		then
			connectError=1
		fi

		echo "$msg"
	fi

	if [[ "$bConnected" == "no" && "$connectError" == "0" ]]
	then
		echo "connecting..."
		if ! msg="$(bluetoothctl connect "$macAddy" 2>&1)"
		then
			connectError=1
		fi

		echo "$msg"
	fi

	# if there are no errors from trying to connect
	# break out of the loop
	# otherwise, loop back and restart scanning
	if [[ "$connectError" == "0" ]]
	then
		break
	fi

done

# TODO better checking for if we're successfully paired

"$loggerPath" "bluetooth-paired" "$logLine" --log-all
