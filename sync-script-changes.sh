#!/usr/bin/env bash

homeScriptsDir="$HOME/bin"
if [[ ! -d "$homeScriptsDir" ]]
then
	echo "no home scripts dir to sync with"
	exit 0
fi

syncScript() {
	path="$1"

	if [[ ! -f "$path" ]]
	then
		echo "script path does not exist"
		exit 1
	fi

	fileName="$(basename "${path%.sh}")"
	pathHome="$homeScriptsDir/$fileName"
	if [[ -x "$pathHome" ]]
	then
		rsync -hau "$pathHome" "$path"
		rsync -hau "$path" "$pathHome"
	fi
}

files="$(git ls-files)"

echo "$files" | while read -r src
do
	if file "$src" | grep -Fiq 'Bourne-Again shell script'
	then
		syncScript "$src"
	fi
done
