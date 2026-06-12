#!/bin/bash

mkdir -p horizontal vertical

for f in *.*; do

    if [ "$f" == "sort_videos.sh" ]; then continue; fi
    res=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$f" 2>/dev/null)

    width=$(echo $res | cut -d'x' -f1)
    height=$(echo $res | cut -d'x' -f2)

    if [[ "$width" =~ ^[0-9]+$ ]] && [[ "$height" =~ ^[0-9]+$ ]]; then
        if [ "$width" -gt "$height" ]; then
            mv "$f" horizontal/
        elif [ "$height" -gt "$width" ]; then
            mv "$f" vertical/
        fi
    fi
done
