FROM alpine

ENV SS_VER 3.3.5
ENV KCP_VER 20210103


ENV SS_URL https://github.com/shadowsocks/shadowsocks-libev/archive/v$SS_VER.tar.gz
ENV SS_DIR shadowsocks-libev-$SS_VER
ENV KCP_URL https://github.com/xtaci/kcptun/releases/download/v${KCP_VER}/kcptun-linux-amd64-${KCP_VER}.tar.gz

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
    rng-tools \
    $(scanelf --needed --nobanner /usr/bin/ss-* \
    | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
    | sort -u) \
    && rm -rf /tmp/repo

COPY supervisord.conf /etc/
COPY 01-kcptun.conf /etc/sysctl.d/

CMD [ "/usr/bin/supervisord", "-c", "/etc/supervisord.conf" ]
