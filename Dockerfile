FROM    alpine:3.10 AS base

## Install libraries by package
RUN     apk add --no-cache --update libgcc libstdc++ zlib-dev libexecinfo-dev

FROM    base AS build

WORKDIR /tmp

ARG     PREFIX=/opt/ovenmediaengine
ARG     MAKEFLAGS="-j16"

ENV     OME_VERSION=temp/alpine \
        OPENSSL_VERSION=1.1.0g \
        SRTP_VERSION=2.2.0 \
        SRT_VERSION=1.3.3 \
        OPUS_VERSION=1.1.3 \
        X264_VERSION=20190513-2245-stable \
        VPX_VERSION=1.7.0 \
        FDKAAC_VERSION=0.1.5 \
        FFMPEG_VERSION=3.4.2

## Install build utils
RUN     apk add --no-cache --update curl perl make gcc musl-dev linux-headers tcl cmake g++ coreutils git autoconf automake libtool diffutils yasm nasm pkgconfig binutils

## Build OpenSSL
RUN \
        DIR=/tmp/openssl && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLf https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz | tar -xz --strip-components=1 && \
        ./config --prefix="${PREFIX}" --openssldir="${PREFIX}" -Wl,-rpath="${PREFIX}/lib" shared no-idea no-mdc2 no-rc5 no-ec2m no-ecdh no-ecdsa no-async && \
        make && \
        make install_sw && \
        rm -rf ${DIR} && \
        rm -rf ${PREFIX}/bin

## Build SRTP
RUN \
        DIR=/tmp/srtp && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLf https://github.com/cisco/libsrtp/archive/v${SRTP_VERSION}.tar.gz | tar -xz --strip-components=1 && \
        ./configure --prefix="${PREFIX}" --enable-shared --disable-static --enable-openssl --with-openssl-dir="${PREFIX}" && \
        make shared_library && \
        make install && \
        rm -rf ${DIR}

## Build SRT
RUN \
        DIR=/tmp/srt && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLf https://github.com/Haivision/srt/archive/v${SRT_VERSION}.tar.gz | tar -xz --strip-components=1 && \
        PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" ./configure \
        --prefix="${PREFIX}" --enable-shared --disable-static && \
        make && \
        make install && \
        rm -rf ${DIR} && \
        rm -rf ${PREFIX}/bin

## Build OPUS
RUN \
        DIR=/tmp/opus && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLf https://archive.mozilla.org/pub/opus/opus-${OPUS_VERSION}.tar.gz | tar -xz --strip-components=1 && \
        autoreconf -fiv && \
        ./configure --prefix="${PREFIX}" --enable-shared --disable-static && \
        make && \
        make install && \
        rm -rf ${PREFIX}/share && \
        rm -rf ${DIR}

## Build X264
RUN \
        DIR=/tmp/x264 && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLf https://download.videolan.org/pub/videolan/x264/snapshots/x264-snapshot-${X264_VERSION}.tar.bz2 | tar -jx --strip-components=1 && \
        ./configure --prefix="${PREFIX}" --enable-shared --enable-pic --disable-cli && \
        make && \
        make install && \
        rm -rf ${DIR}

## Build VPX
RUN \
        DIR=/tmp/vpx && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLf https://codeload.github.com/webmproject/libvpx/tar.gz/v${VPX_VERSION} | tar -xz --strip-components=1 && \
        ./configure --prefix="${PREFIX}" --enable-vp8 --enable-pic --enable-shared --disable-static --disable-vp9 --disable-debug --disable-examples --disable-docs --disable-install-bins && \
        make && \
        make install && \
        rm -rf ${DIR}

## Build FDK-AAC
RUN \
        DIR=/tmp/aac && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLf https://github.com/mstorsjo/fdk-aac/archive/v${FDKAAC_VERSION}.tar.gz | tar -xz --strip-components=1 && \
        autoreconf -fiv && \
        ./configure --prefix="${PREFIX}" --enable-shared --disable-static --datadir=/tmp/aac && \
        make && \
        make install && \
        rm -rf ${DIR}

## Build FFMPEG
RUN \
        DIR=/tmp/ffmpeg && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLf https://www.ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2 | tar -jx --strip-components=1 && \
        PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" ./configure \
        --prefix="${PREFIX}" \
        --enable-gpl \
        --enable-nonfree \
        --extra-cflags="-I${PREFIX}/include"  \
        --extra-ldflags="-L${PREFIX}/lib -Wl,-rpath,${PREFIX}/lib" \
        --extra-libs=-ldl \
        --enable-shared \
        --disable-static \
        --disable-debug \
        --disable-doc \
        --disable-programs \
        --disable-avdevice --disable-dct --disable-dwt --disable-error-resilience --disable-lsp --disable-lzo --disable-rdft --disable-faan --disable-pixelutils \
        --disable-everything \
        --enable-zlib --enable-libopus --enable-libvpx --enable-libfdk_aac --enable-libx264 \
        --enable-encoder=libvpx_vp8,libvpx_vp9,libopus,libfdk_aac,libx264 \
        --enable-decoder=aac,aac_latm,aac_fixed,h264 \
        --enable-parser=aac,aac_latm,aac_fixed,h264 \
        --enable-filter=asetnsamples,aresample,aformat,channelmap,channelsplit,scale,transpose,fps,settb,asettb && \
        make && \
        make install && \
        rm -rf ${PREFIX}/share && \
        rm -rf ${DIR}

## Build OvenMediaEngine
RUN \
        DIR=/tmp/ome && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLf https://github.com/AirenSoft/OvenMediaEngine/archive/${OME_VERSION}.tar.gz | tar -xz --strip-components=1 && \
        cd src && \
        make release && \
        mkdir -p ${PREFIX}/bin/conf && \
        strip ./bin/RELEASE/OvenMediaEngine && \
        cp ./bin/RELEASE/OvenMediaEngine ${PREFIX}/bin/ && \
        cp ../misc/conf_examples/Server.xml ${PREFIX}/bin/conf/ && \
        rm -rf ${DIR}


FROM base AS release
MAINTAINER  Jeheon Han <getroot@airensoft.com>

WORKDIR         /opt/ovenmediaengine/bin
EXPOSE          80/tcp 1953/tcp 3333/tcp 10000-10005/udp 9000/udp

COPY            --from=build /opt/ovenmediaengine /opt/ovenmediaengine

ENTRYPOINT      ["/opt/ovenmediaengine/bin/OvenMediaEngine"]