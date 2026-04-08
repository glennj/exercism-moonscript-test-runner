FROM ubuntu:24.04 AS builder

ENV LUA_VER="5.4.8"
ENV LUA_CHECKSUM="4f18ddae154e793e46eeab727c59ef1c0c0c2b744e7b94219710d76f530629ae"
ENV LUAROCKS_VER="3.12.0"
ENV LUAROCKS_GPG_KEY="3FD8F43C2BB3C478"

RUN apt-get update && \
    apt-get install -y curl gcc make unzip gnupg git && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get purge --auto-remove && \
    apt-get clean

RUN curl -R -O -L http://www.lua.org/ftp/lua-${LUA_VER}.tar.gz && \
    [ "$(sha256sum lua-${LUA_VER}.tar.gz | cut -d' ' -f1)" = "${LUA_CHECKSUM}" ] && \
    tar -zxf lua-${LUA_VER}.tar.gz && \
    cd lua-${LUA_VER} && \
    make all install && \
    cd .. && \
    rm lua-${LUA_VER}.tar.gz && \
    rm -rf lua-${LUA_VER}

RUN curl -R -O -L https://luarocks.org/releases/luarocks-${LUAROCKS_VER}.tar.gz && \
    curl -R -O -L https://luarocks.org/releases/luarocks-${LUAROCKS_VER}.tar.gz.asc && \
    gpg --keyserver keyserver.ubuntu.com --recv-keys ${LUAROCKS_GPG_KEY} && \
    gpg --verify luarocks-${LUAROCKS_VER}.tar.gz.asc luarocks-${LUAROCKS_VER}.tar.gz && \
    tar -zxpf luarocks-${LUAROCKS_VER}.tar.gz && \
    cd luarocks-${LUAROCKS_VER} && \
    ./configure && make && make install && \
    cd .. && \
    rm luarocks-${LUAROCKS_VER}.tar.gz.asc && \
    rm luarocks-${LUAROCKS_VER}.tar.gz && \
    rm -rf luarocks-${LUAROCKS_VER}

RUN luarocks install busted
RUN luarocks install alt-getopt
RUN luarocks install moonscript
RUN luarocks install date
RUN luarocks install lua-tz
RUN luarocks install luatz

FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y jq tzdata && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get purge --auto-remove && \
    apt-get clean

COPY --from=builder /usr/local /usr/local

COPY . /opt/test-runner
WORKDIR /opt/test-runner
ENTRYPOINT ["/opt/test-runner/bin/run.moon"]
