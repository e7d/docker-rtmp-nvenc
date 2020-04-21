ARG FFMPEG_LIB_DEPS="libfdk-aac-dev libomxil-bellagio-dev libv4l-dev libvorbis-dev libvpx-dev libwebp-dev libx264-dev libx265-dev libxvidcore-dev"

FROM nvidia/cuda:10.2-devel-ubuntu18.04 as ffmpeg-build

ARG FFMPEG_LIB_DEPS

# https://www.nasm.us/pub/nasm/releasebuilds/
ENV NASM_VERSION 2.14.02
# https://github.com/FFmpeg/nv-codec-headers/releases
ENV NVCODEC_VERSION 9.1.23.1
# https://ffmpeg.org/releases/
ENV FFMPEG_VERSION 4.2.2

RUN apt-get update \
    && apt-get install -y autoconf curl git $FFMPEG_LIB_DEPS

RUN curl -fsSLO https://www.nasm.us/pub/nasm/releasebuilds/$NASM_VERSION/nasm-$NASM_VERSION.tar.bz2 \
    && tar -xjf nasm-$NASM_VERSION.tar.bz2 \
    && cd nasm-$NASM_VERSION \
    && ./autogen.sh \
    && ./configure \
    && make -j$(nproc) \
    && make install

RUN git clone -b n$NVCODEC_VERSION --depth 1 https://git.videolan.org/git/ffmpeg/nv-codec-headers \
    && cd nv-codec-headers \
    && make install

ENV PKG_CONFIG_PATH /usr/local/lib/pkgconfig
RUN apt-get install -y pkg-config \
    && curl -fsSLO https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.bz2 \
    && tar -xjf ffmpeg-$FFMPEG_VERSION.tar.bz2 \
    && cd ffmpeg-$FFMPEG_VERSION \
    && ./configure --prefix=/usr \
    --disable-debug \
    --enable-cuda \
    --enable-cuvid \
    --enable-gpl \
    --enable-libfdk-aac \
    --enable-libnpp \
    --enable-libv4l2 \
    --enable-libvorbis \
    --enable-libvpx \
    --enable-libwebp \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libxvid \
    --enable-nonfree \
    --enable-nvdec \
    --enable-nvenc \
    --enable-omx \
    --enable-version3 \
    --extra-cflags=-I/usr/local/cuda/include \
    --extra-ldflags=-L/usr/local/cuda/lib64 \
    && make -j$(nproc) \
    && make install

FROM nvidia/cuda:10.2-runtime-ubuntu18.04 as ffmpeg-deps

ARG FFMPEG_LIB_DEPS

RUN apt-get update \
    && apt-get install -y $FFMPEG_LIB_DEPS \
    && rm -rf /tmp/build

FROM ffmpeg-deps as nginx-rtmp-build

ARG BUILD_DEPS="build-essential libpcre3-dev libssl-dev wget zlib1g-dev"

ENV NGINX_VERSION nginx-1.15.0
ENV NGINX_RTMP_MODULE_VERSION 1.2.1

RUN apt-get update \
    && apt-get install -y ca-certificates openssl $BUILD_DEPS

RUN mkdir -p /tmp/build/nginx \
    && cd /tmp/build/nginx \
    && wget -O ${NGINX_VERSION}.tar.gz https://nginx.org/download/${NGINX_VERSION}.tar.gz \
    && tar -zxf ${NGINX_VERSION}.tar.gz

RUN mkdir -p /tmp/build/nginx-rtmp-module \
    && cd /tmp/build/nginx-rtmp-module \
    && wget -O nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz https://github.com/arut/nginx-rtmp-module/archive/v${NGINX_RTMP_MODULE_VERSION}.tar.gz \
    && tar -zxf nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz \
    && cd nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}

RUN cd /tmp/build/nginx/${NGINX_VERSION} \
    && ./configure \
    --sbin-path=/usr/local/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --pid-path=/var/run/nginx/nginx.pid \
    --lock-path=/var/lock/nginx/nginx.lock \
    --http-log-path=/var/log/nginx/access.log \
    --http-client-body-temp-path=/tmp/nginx-client-body \
    --with-http_ssl_module \
    --with-threads \
    --with-ipv6 \
    --add-module=/tmp/build/nginx-rtmp-module/nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION} \
    && make -j$(nproc) \
    && make install \
    && mkdir /var/lock/nginx \
    && apt-get autoremove --purge -y $BUILD_DEPS \
    && rm -rf /tmp/build

FROM ffmpeg-deps

ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,video,utility

COPY --from=ffmpeg-build /usr/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=ffmpeg-build /usr/bin/ffprobe /usr/bin/ffprobe
COPY --from=nginx-rtmp-build / /
COPY /host /

RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

RUN ffmpeg -version

EXPOSE 1935

CMD ["nginx", "-g", "daemon off;"]
