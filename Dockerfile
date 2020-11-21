FROM tiredofit/alpine:3.12 as konnect-builder

ARG KONNECT_REPO_URL
ARG KONNECT_VERSION

ENV KONNECT_REPO_URL=${KONNECT_REPO_URL:-"https://github.com/Kopano-dev/konnect"} \
    KONNECT_VERSION=${KONNECT_VERSION:-"v0.33.10"}

#ADD build-assets/kopano-konnect /build-assets

RUN set -x && \
    apk update && \
    apk upgrade && \
    apk add -t .konnect-build-deps \
                build-base \
                coreutils \
                gettext \
                git \
                go \
                imagemagick \
                nodejs \
                py-pip \
                tar \
                yarn \
                && \
    pip3 install scour && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    \
    ### Build Konnect
    git clone ${KONNECT_REPO_URL} /usr/src/konnect && \
    cd /usr/src/konnect && \
    git checkout ${KONNECT_VERSION} && \
    \
    if [ -d "/build-assets/src/konnect" ] ; then cp -R /build-assets/src/konnect/* /usr/src/konnect ; fi; \
    if [ -f "/build-assets/scripts/konnect.sh" ] ; then /build-assets/scripts/konnect.sh ; fi; \
    \
    make && \
    make dist && \
    export KONNECT_VERSION=$(echo ${KONNECT_VERSION} | sed "s|v||g") && \
    mkdir -p /rootfs/usr/libexec/kopano/ && \
    cp -R /usr/src/konnect/dist/kopano-konnect-${KONNECT_VERSION}/konnectd /rootfs/usr/libexec/kopano && \
    mkdir -p /rootfs/usr/share/kopano-konnect/identifier-webapp && \
    cp -R /usr/src/konnect/dist/kopano-konnect-${KONNECT_VERSION}/identifier-webapp/* /rootfs/usr/share/kopano-konnect/identifier-webapp/ && \
    mkdir -p /rootfs/assets/kopano/config/konnect && \
    cp -R /usr/src/konnect/dist/kopano-konnect-${KONNECT_VERSION}/*.in /rootfs/assets/kopano/config/konnect && \
    mkdir -p /rootfs/tiredofit && \
    echo "Konnnect ${KONNECT_VERSION} built from ${KONNECT_REPO_URL} on $(date)" > /rootfs/tiredofit/konnect.version && \
    echo "Commit: $(cd /usr/src/konnect ; echo $(git rev-parse HEAD))" >> /rootfs/tiredofit/konnect.version && \
    cd /rootfs && \
    tar cvfz /kopano-konnect.tar.gz . && \
    cd / && \
    apk del .konnect-build-deps && \
    rm -rf /usr/src/* && \
    rm -rf /var/cache/apk/* && \
    rm -rf /rootfs

FROM tiredofit/nginx:latest
LABEL maintainer="Dave Conroy (dave at tiredofit dot ca)"

ENV ENABLE_SMTP=FALSE \
    NGINX_ENABLE_CREATE_SAMPLE_HTML=FALSE \
    NGINX_LOG_ACCESS_LOCATION=/logs/nginx \
    NGINX_LOG_ERROR_LOCATION=/logs/nginx \
    NGINX_MODE=PROXY \
    NGINX_PROXY_URL=http://localhost:8777 \
    ZABBIX_HOSTNAME=konnect-app

### Move Previously built files from builder image
COPY --from=konnect-builder /*.tar.gz /usr/src/konnect/

RUN set -x && \
    apk update && \
    apk upgrade && \
    apk add -t .konnect-run-deps \
                openssl \
                && \
    \
    ##### Unpack Konnect
    tar xvfz /usr/src/konnect/kopano-konnect.tar.gz -C / && \
    rm -rf /usr/src/* && \
    rm -rf /etc/kopano && \
    ln -sf /config /etc/kopano && \
    rm -rf /var/cache/apk/*

ADD install /
