FROM alpine:3 as builder

ARG ZBX_VERSION=4.4.0
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git
ARG BUILD_DATE
ARG VCS_REF
ARG APK_FLAGS_COMMON=""
ARG APK_FLAGS_PERSISTENT="${APK_FLAGS_COMMON} --clean-protected --no-cache"
ARG APK_FLAGS_DEV="${APK_FLAGS_COMMON} --no-cache"

RUN set -eux && \
    apk update && \
    apk add ${APK_FLAGS_DEV} --virtual build-dependencies \
            alpine-sdk \
            autoconf \
            automake \
            curl-dev \
            openssl-dev \
            openldap-dev \
            pcre-dev \
            git \
            go \
            bash \
            coreutils \
            iputils \
            pcre \
            libcurl \
            libldap \
            coreutils

RUN  cd /tmp/ && \
    git clone ${ZBX_SOURCES} --branch ${ZBX_VERSION} --depth 1 --single-branch zabbix-${ZBX_VERSION} && \
    cd /tmp/zabbix-${ZBX_VERSION} && \
    zabbix_revision=`git rev-parse --short HEAD` && \
    sed -i "s/{ZABBIX_REVISION}/$zabbix_revision/g" include/version.h && \
    ./bootstrap.sh && \
    export CFLAGS="-fPIC -pie -Wl,-z,relro -Wl,-z,now" && \
    ./configure --enable-agent2 \
            --datadir=/usr/lib \
            --libdir=/usr/lib/zabbix \
            --prefix=/usr \
            --sysconfdir=/etc/zabbix \
            --prefix=/usr \
            --with-libcurl \
            --with-ldap \
            --with-openssl \
            --enable-ipv6 \
            --silent

COPY plugins/ /tmp/zabbix-${ZBX_VERSION}/go/src/zabbix/plugins/

ENV GOPATH=/opt/go
RUN \
  cd /tmp/zabbix-${ZBX_VERSION} \
  &&  make install \
  &&  ls /usr/sbin/ | grep -q zabbix_agent2


FROM alpine:3

LABEL maintainer="Monitorig Artist <info@monitoringartist.com>"

ARG APK_FLAGS_COMMON=""
ARG APK_FLAGS_PERSISTENT="${APK_FLAGS_COMMON} --clean-protected --no-cache"
ARG APK_FLAGS_DEV="${APK_FLAGS_COMMON} --no-cache"

RUN set -eux && \
    apk update && \
    apk add ${APK_FLAGS_DEV} \
            pcre \
            libcurl \
            libldap

STOPSIGNAL SIGTERM

COPY --from=builder /usr/sbin/zabbix_agent2 /usr/sbin/zabbix_agent2
COPY --from=builder /etc/zabbix/zabbix_agent2.conf /etc/zabbix/zabbix_agent2.conf

CMD /usr/sbin/zabbix_agent2 -f
