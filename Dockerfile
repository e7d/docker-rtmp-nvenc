FROM nvidia/cuda:10.0-devel-ubuntu18.04 as ffmpeg-build

# https://www.nasm.us/pub/nasm/releasebuilds/
ENV NASM_VERSION 2.14
# https://github.com/FFmpeg/nv-codec-headers/releases
ENV NVCODEC_VERSION 9.1.23.1
# https://ffmpeg.org/releases/
ENV FFMPEG_VERSION 4.2.2

RUN apt-get update \
    && apt-get install -y autoconf curl git pkg-config

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
RUN curl -fsSLO https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.bz2 \
    && tar -xjf ffmpeg-$FFMPEG_VERSION.tar.bz2 \
    && cd ffmpeg-$FFMPEG_VERSION \
    && ./configure \
    --enable-cuda \
    --enable-cuvid \
    --enable-nvenc \
    --enable-nonfree \
    --enable-libnpp \
    --extra-cflags=-I/usr/local/cuda/include \
    --extra-ldflags=-L/usr/local/cuda/lib64 \
    && make -j$(nproc) \
    && make install

FROM nvidia/cuda:10.0-runtime-ubuntu18.04

ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,video,utility

COPY --from=ffmpeg-build /usr/local/bin/ffmpeg /usr/local/bin/ffmpeg
COPY --from=ffmpeg-build /usr/local/bin/ffprobe /usr/local/bin/ffprobe

ENV NGINX_VERSION nginx-1.15.0
ENV NGINX_RTMP_MODULE_VERSION 1.2.1

RUN apt-get update \
    && apt-get install -y build-essential ca-certificates libpcre3-dev libssl-dev openssl wget zlib1g-dev

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
    && rm -rf /tmp/build

RUN apt-get autoremove --purge -y build-essential libpcre3-dev libssl-dev wget zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

COPY /host /

EXPOSE 1935

CMD ["nginx", "-g", "daemon off;"]
