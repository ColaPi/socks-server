FROM alpine

ENV SS_VER 3.3.4
ENV V2RAY_VER 1.3.1
ENV KCP_VER 20200701
ENV TROJAN_VER 0.5.0

ENV SS_URL https://github.com/shadowsocks/shadowsocks-libev/archive/v$SS_VER.tar.gz
ENV SS_DIR shadowsocks-libev-$SS_VER
ENV KCP_URL https://github.com/xtaci/kcptun/releases/download/v${KCP_VER}/kcptun-linux-amd64-${KCP_VER}.tar.gz
ENV TROJAN_URL https://github.com/p4gefau1t/trojan-go/releases/download/v${TROJAN_VER}/trojan-go-linux-amd64.zip
ENV V2RAY_PLUGIN_URL https://github.com/shadowsocks/v2ray-plugin/releases/download/v${V2RAY_VER}/v2ray-plugin-linux-amd64-v${V2RAY_VER}.tar.gz
# Build shadowsocks-libev
RUN set -ex \
    # Build environment setup
    && apk add --no-cache --virtual .build-deps \
    autoconf \
    automake \
    build-base \
    c-ares-dev \
    libev-dev \
    libtool \
    libsodium-dev \
    linux-headers \
    mbedtls-dev \
    pcre-dev \
    curl \
    tar \
    git \
    # Download kcptun
    && curl -sSL $KCP_URL | tar xz -C /usr/bin/ client_linux_amd64 server_linux_amd64 \
    # Download v2ray plugin
    && curl -sSL $V2RAY_PLUGIN_URL | tar xz -C /usr/bin/ v2ray-plugin_linux_amd64 \
    # Download trojan
    && mkdir /tmp/repo \
    && wget --no-check-certificate https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.31-r0/glibc-2.31-r0.apk -P /tmp/repo/ \
    && apk add --repositories-file=/dev/null --allow-untrusted --no-network --no-cache /tmp/repo/glibc-2.31-r0.apk \
    && rm -rf /tmp/repo/glibc-2.31-r0.apk \
    && wget ${TROJAN_URL} -O trojan-go-linux-amd64.zip\
    && unzip trojan-go-linux-amd64.zip \
    && mv trojan-go geoip.dat geosite.dat /usr/bin/ \
    && rm -rf example trojan-go-linux-amd64.zip \
    # Build & install shadowsocks
    && curl -sSL $SS_URL | tar xz \
    && cd $SS_DIR \
    && curl -sSL https://github.com/shadowsocks/ipset/archive/shadowsocks.tar.gz | tar xz --strip 1 -C libipset \
    && curl -sSL https://github.com/shadowsocks/libcork/archive/shadowsocks.tar.gz | tar xz --strip 1 -C libcork \
    && curl -sSL https://github.com/shadowsocks/libbloom/archive/master.tar.gz | tar xz --strip 1 -C libbloom \
    && ./autogen.sh \
    && ./configure --prefix=/usr --disable-documentation \
    && make install \
    && cd .. \
    && rm -rf $SS_DIR \
    && apk del .build-deps \
    # Runtime dependencies setup
    && apk add --no-cache --update \
    rng-tools \
    libstdc++ \
    iptables \
    supervisor \
    $(scanelf --needed --nobanner /usr/bin/ss-* \
    | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
    | sort -u) \
    && rm -rf /tmp/repo

COPY supervisord.conf /etc/
COPY 01-kcptun.conf /etc/sysctl.d/

CMD [ "/usr/bin/supervisord", "-c", "/etc/supervisord.conf" ]
