#!/bin/sh
src=$1
dest=$2
bw=$3
ffmpeg -vsync 0 -hwaccel cuvid -c:v h264_cuvid -i $src -c:a copy -c:v h264_nvenc -b $bw -minrate $bw -maxrate $bw -bufsize $bw -f flv $dest
