# docker-rtmp-nvenc
A docker gateway container between your PC and streaming services (Twitch, YouTube...), using NVENC as encoder.

## Prerequisites
To use NVENC, you need a [compatible Nvidia card](https://developer.nvidia.com/video-encode-decode-gpu-support-matrix) and the [NVIDIA Container Toolkit](https://github.com/NVIDIA/nvidia-docker) for [Docker](https://docs.docker.com/get-started/) to be setup properly.

## How to run

`docker run -d --runtime nvidia --name rtmp-nvenc -p 1935:1935 e7db/rtmp-nvenc`

## Test with OBS Studio and VLC

In OBS, use the following settings:
- **Stream type:** Custom Streaming Server
- **URL:** rtmp://<ip_of_host>/local
- **Stream key:** test

Start streaming, then, go to VLC and and test your stream with the URL `rtmp://<ip_of_host>/live/test`. 

Remember to replace <ip_of_host> with your server IP.

## Go live

Multiple default NVENC-based configurations are available for the following platforms:
- Facebook Live, using `rtmp://<ip_of_host>/facebook`
- Mixer, using `rtmp://<ip_of_host>/mixer`
- Twitter Periscope, using `rtmp://<ip_of_host>/periscope`
- Restream, using `rtmp://<ip_of_host>/restream`
- Twitch, using `rtmp://<ip_of_host>/twitch`
- YouTube, using `rtmp://<ip_of_host>/youtube`

## Go live with custom settings

You can also use custom settings, to go Live on another platform or with any specific encoder settings you want. you can also use standard CPU-based x264 if you prefer.

For example, you could go live on Twitch with 4MBps bitrate using the following configuration:
```
application twitch {
    live on;
    exec_push ffmpeg -hwaccel cuvid -c:v h264_cuvid -i rtmp://localhost/twitch/$name -vsync 0 -c:a copy -c:v h264_nvenc -preset hq -profile high -rc cbr -b 4M -bufsize 4M -f flv rtmp://live.twitch.tv/app/$name >>/dev/stdout 2>&1;
}
```

You can then use this specific configuration by starting the container like this:

`docker run -d --runtime nvidia --name rtmp-nvenc -p 1935:1935 -v /path/to/custom.conf:/etc/nginx/rtmp-conf.d/custom.conf e7db/rtmp-nvenc`
