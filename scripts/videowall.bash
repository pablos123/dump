#!/usr/bin/env bash
# Deps: ffmpeg, imagemagick (convert), pngswall (set $PNGSWALL or put on PATH)

pngswall="${PNGSWALL:-pngswall}"

help='
  ▌ ▐·▪  ·▄▄▄▄  ▄▄▄ .      ▄▄▌ ▐ ▄▌ ▄▄▄· ▄▄▌  ▄▄▌
 ▪█·█▌██ ██▪ ██ ▀▄.▀·▪     ██· █▌▐█▐█ ▀█ ██•  ██•
 ▐█▐█•▐█·▐█· ▐█▌▐▀▀▪▄ ▄█▀▄ ██▪▐█▐▐▌▄█▀▀█ ██▪  ██▪
  ███ ▐█▌██. ██ ▐█▄▄▌▐█▌.▐▌▐█▌██▐█▌▐█ ▪▐▌▐█▌▐▌▐█▌▐▌
 . ▀  ▀▀▀▀▀▀▀▀•  ▀▀▀  ▀█▄▀▪ ▀▀▀▀ ▀▪ ▀  ▀ .▀▀▀ .▀▀▀

Show a video as wallpaper.
Prepare a video: videowall -p <video> [-t <limit video to some second>] (this sets the video too)
Set the video: videowall
Quit: videowall -q
The prepared video is located in ~/.videowall
'

video=
limit=
quit=false
while getopts p:l:qh opt; do
    case "${opt}" in
    p) video="${OPTARG}" ;;
    l) limit="-t ${OPTARG}" ;;
    q) quit=true ;;
    h) echo "${help}" && exit 0 ;;
    *) echo "Usage: videowall [-p '<video>' -l '<limit_in_seconds>']" && exit 1 ;;
    esac
done

if [[ $(pgrep -c videowall) -gt 1 ]]; then
    pgrep --oldest videowall | xargs kill -9
fi

if ${quit}; then
    pgrep videowall | xargs kill -9
fi

if [[ -n ${video} ]]; then
    echo "Preparing video... 🧙"
    rm -rf "${HOME}/.videowall"
    mkdir -p "${HOME}/.videowall"
    eval "(ffmpeg -y -ss 00:00:00.000 ${limit} -i '${video}' '${HOME}/.videowall/%d.png' > /dev/null 2>&1) || echo 'Error! Check options and run again'"
    find "${HOME}/.videowall/" -type f -exec convert {} -resize '1920x1080!' png32:{} \;
fi

if [[ -d "${HOME}/.videowall" ]]; then
    total_files=$(($(find "${HOME}/.videowall" | wc -l) - 1))
    if [[ -z ${total_files} ]]; then
        echo "Prepare a video first!"
        exit 1
    fi
    iterator=1
    (while true; do
        "${pngswall}" "${HOME}/.videowall/${iterator}.png" >/dev/null 2>&1
        (( iterator += 1 ))
        if (( iterator > total_files )); then
            iterator=1
        fi
    done) &
    disown
else
    echo "Prepare a video first!"
    exit 1
fi
