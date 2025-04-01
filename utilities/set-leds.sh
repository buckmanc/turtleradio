#!/usr/bin/env bash

if [[ -z "$HAS_PINCTRL" ]]
then
	if ( type pinctrl >/dev/null 2>&1 )
	then
		export HAS_PINCTRL=1
	else
		export HAS_PINCTRL=0
	fi
fi

# back out if pinctrl is not installed
if [[ "$HAS_PINCTRL" == 0 ]]
then
	exit 0
	# pinctrl() {
	# 	:
	# }
fi

# set according to what pins your leds are plugged into
# if you have no leds this has no function
# designed for the pi stoplight, but should work fine for any set of 3 pins
red=9
yellow=10
green=11

# dl = driving low, aka "off"
# dh = driving high, aka "on"
redPowerArg="dl"
yellowPowerArg="dl"
greenPowerArg="dl"

ledArg="${1,,}"

# turn on the led specified and all others off
# otherwise, turn them all off
if [[ "$ledArg" == "red" ]]
then
		redPowerArg="dh"
		echo "leds: red"
elif [[ "$ledArg" == "yellow" ]]
then
		yellowPowerArg="dh"
		echo "leds: yellow"
elif [[ "$ledArg" == "green" ]]
then
		greenPowerArg="dh"
		echo "leds: green"
elif [[ "$ledArg" == "test"* ]]
then
	existingColor=''
	if [[ "$(pinctrl get $green)" == *"| hi"* ]]
	then
		existingColor="green"
	elif [[ "$(pinctrl get $yellow)" == *"| hi"* ]]
	then
		existingColor="yellow"
	elif [[ "$(pinctrl get $red)" == *"| hi"* ]]
	then
		existingColor="red"
	fi
	
	sleepies="0.1"
	loops="2"

	# animate the lights a little
	for i in $(seq 1 "$loops")
	do
		if [[ "$ledArg" == "test" || "$ledArg" == "test1" ]]
		then
			"$0" green && sleep "$sleepies"
			"$0" yellow && sleep "$sleepies"
			"$0" red && sleep "$sleepies"
			"$0" && sleep "$sleepies"
		elif [[ "$ledArg" == "test2" ]]
		then
			"$0" green && sleep "$sleepies"
			"$0" yellow && sleep "$sleepies"
			"$0" && sleep "$sleepies"
		elif [[ "$ledArg" == "test3" ]]
		then
			"$0" green && sleep "$sleepies"
			"$0" && sleep "$sleepies"
		else
			# dupe error check but oh well
			echo "bad led arg"
			exit 1
		fi
	done

	# restore the starting led state
	"$0" "$existingColor"
	exit 0
elif [[ -n "$ledArg" ]]
then
		echo "bad led arg"
		exit 1
elif [[ -z "$ledArg" ]]
then
	echo "leds: off"
fi

pinctrl set "$red" op "$redPowerArg"
pinctrl set "$yellow" op "$yellowPowerArg"
pinctrl set "$green" op "$greenPowerArg"

