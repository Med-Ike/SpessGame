#!/usr/bin/env bash
set -eo pipefail

FAILED=0
shopt -s globstar

exactly() { # exactly N name search [mode] [filter]
	count="$1"
	name="$2"
	search="$3"
	mode="${4:--E}"
	filter="${5:-**/*.dm}"

	num="$(grep "$mode" "$search" $filter | wc -l || true)"

	if [ $num -eq $count ]; then
		echo "$num $name"
	else
		echo "$(tput setaf 9)$num $name (expecting exactly $count)$(tput sgr0)"
		FAILED=1
	fi
}

# With the potential exception of << if you increase any of these numbers you're probably doing it wrong
# Additional exception August 2020: \b is a regex symbol as well as a BYOND macro.
exactly 1 "escapes" '\\\\(red|blue|green|black|b|i[^mc])'
exactly 4 "Del()s" '\WDel\('
exactly 2 "/atom text paths" '"/atom'
exactly 2 "/area text paths" '"/area'
exactly 2 "/datum text paths" '"/datum'
exactly 2 "/mob text paths" '"/mob'
exactly 6 "/obj text paths" '"/obj'
exactly 8 "/turf text paths" '"/turf'
exactly 1 "world<< uses" 'world<<|world[[:space:]]<<'
exactly 1 "world.log<< uses" 'world.log<<|world.log[[:space:]]<<'
exactly 137 "<< uses" '(?<!<)<<(?!<)' -P
exactly 0 "incorrect indentations" '^( {4,})' -P
exactly 19 "text2path uses" 'text2path'
exactly 3 "update_icon() override" '/update_icon\((.*)\)'  -P
exactly 1 "goto uses" 'goto '
exactly 6 "atom/New uses" '^/(obj|atom|area|mob|turf).*/New\('
exactly 0 "tag uses" '\stag = ' -P '**/*.dmm'
# With the potential exception of << if you increase any of these numbers you're probably doing it wrong

broken_files=0
while read -r file; do
	ftype="$(uchardet "$file")"
	case "$ftype" in
		ASCII)
			continue;;
		UTF-8)
			if diff -d "$file" <(<"$file" iconv -c -f utf8 -t iso8859-1 2>/dev/null | tr -d $'\x7F-\x9F' | iconv -c -f iso8859-1 -t utf8 2>/dev/null); then
				continue
			else
				echo "$file contains Unicode characters outside the ISO 8859-1 character set"
				(( broken_files = broken_files + 1 ))
			fi;;
		*)
			if diff -d "$file" <(<"$file" tr -d $'\x7F-\x9F' | iconv -c -f iso8859-1 -t utf8 2>/dev/null | iconv -c -f utf8 -t iso8859-1 2>/dev/null); then
				continue
			else
				echo "$file contains characters outside the ISO 8859-1 character set"
				(( broken_files = broken_files + 1 ))
			fi;;
	esac
done < <(find . -name '*.dm')
echo "$broken_files files with invalid characters"
if (( broken_files > 0 )); then
	FAILED=1
fi

num=`find ./html/changelogs -not -name "*.yml" | wc -l`
echo "$num non-yml files (expecting exactly 2)"
[ $num -eq 2 ] || FAILED=1

num=`find . -perm /111 -name "*.dm*" | wc -l`
echo "$num executable *.dm? files (expecting exactly 0)"
[ $num -eq 0 ] || FAILED=1

exit $FAILED
