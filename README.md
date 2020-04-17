# docker-rtmp-nvenc
A docker gateway container between your PC and streaming services (Twitch, YouTube...), using NVENC as encoder.

## Prerequisites
To use NVENC, you need a [compatible Nvidia card](https://developer.nvidia.com/video-encode-decode-gpu-support-matrix) and the [NVIDIA Container Toolkit](https://github.com/NVIDIA/nvidia-docker) for [Docker](https://docs.docker.com/get-started/) to be setup properly.

## How to run
`docker run -d --runtime nvidia -p 1935:1935 --name rtmp-nvenc e7db/rtmp-nvenc`

## Test with OBS Studio and VLC
Settings:
- **Stream type:** Custom Streaming Server
- **URL:** rtmp://<ip_of_host>/live
- **Stream key:** Anything. For example, `test`.
Go to VLC and and test your stream with the URL `rtmp://<ip_of_host>/live/<key>`.

## Go live on Twitch or YouTube
Use the following URL:
- **Twitch:** `rtmp://<ip_of_host>/twitch`
- **YouTube:** `rtmp://<ip_of_host>/youtube`

## Go live on another platform
The current nginx.conf contains:
```conf
worker_processes auto;
rtmp_auto_push on;

events {
}

rtmp {
    server {
        listen 1935;
        listen [::]:1935 ipv6only=on;

        application live {
            live on;
            record off;
        }

        application twitch {
            live on;
            record off;
            exec_push /usr/local/bin/ffmpeg -vsync 0 -hwaccel cuvid -c:v h264_cuvid -i rtmp://localhost/twitch/$name -c:a copy -c:v h264_nvenc -b 6000k -minrate 6000k -maxrate 6000k -bufsize 6000k -f flv rtmp://live.twitch.tv/app/$name >>/dev/stdout 2>&1;
        }

        application youtube {
            live on;
            record off;
            exec_push /usr/local/bin/ffmpeg -vsync 0 -hwaccel cuvid -c:v h264_cuvid -i rtmp://localhost/youtube/$name -c:a copy -c:v h264_nvenc -b 6000k -minrate 6000k -maxrate 6000k -bufsize 6000k -f flv rtmp://a.rtmp.youtube.com/live2/$name >>/dev/stdout 2>&1;
        }
    }
}
```
Based on that, you can extend this container to pretty much any streaming service compatible with RTMP.
