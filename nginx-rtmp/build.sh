#!/usr/bin/env bash
set -e

# ================================================
# Prep the env
# ================================================

if [ "$EUID" -ne 0 ]; then
    echo "This script uses functionality which requires root privileges"
    exit 1
fi

# In the event of the script exiting, end the build
acbuildEnd() {
    export EXIT=$?
    acbuild --debug end && exit $EXIT
}
trap acbuildEnd EXIT

# ================================================
# Set variables for build
# ================================================

## Version of this build. Increment for each new feature
VERSION="0.0.1"

IMAGE_NAME="xplex.me/nginx-rtmp"

NGINX_VERSION="1.10.2"
NGINX_RTMP_MODULE_VERSION="1.1.10"

NGINX_BUILD_DEPS="\
		gcc \
		libc-dev \
		make \
		openssl-dev \
		pcre-dev \
		zlib-dev \
		linux-headers \
		curl \
		gnupg \
		libxslt-dev"

# ================================================
# Build set up
# ================================================

## Begin the build
acbuild --debug begin docker://alpine:3.4

## Name the ACI
acbuild --debug set-name ${IMAGE_NAME}

# ================================================
# Nginx installation set up
# ================================================

## Update package list
acbuild --debug run -- apk update

## Add nginx group and user
acbuild --debug run -- addgroup -S nginx
acbuild --debug run -- adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx

## Install build deps
acbuild --debug run -- apk add --no-cache --virtual .build-deps ${NGINX_BUILD_DEPS}

## Install ffmpeg and cacertificates
acbuild --debug run -- apk add --no-cache ca-certificates ffmpeg

## Get nginx sources
acbuild --debug run -- curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz
acbuild --debug run -- curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc

## Get nginx-rtmp-module sources
acbuild --debug run -- curl -fSL https://github.com/arut/nginx-rtmp-module/archive/v${NGINX_RTMP_MODULE_VERSION}.tar.gz -o nginx-rtmp-module.tar.gz

# ================================================
# Do the build from source
# ================================================

## Add, run and remove build from source script
acbuild --debug copy build-from-src.sh /build-from-src.sh
acbuild --debug run -- /build-from-src.sh $NGINX_VERSION $NGINX_RTMP_MODULE_VERSION
acbuild --debug run -- rm /build-from-src.sh

## Get missing nginx dependencies
acbuild --debug run -- apk add --no-cache --virtual .gettext gettext
acbuild --debug run -- mkdir -p /var/tmp/
acbuild --debug run -- mv /usr/bin/envsubst /var/tmp/

RUN_DEPS=$(acbuild --debug run -- /bin/sh -c "scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst" | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' | sort -u)

acbuild --debug run -- apk add --no-cache --virtual .nginx-rundeps $RUN_DEPS
acbuild --debug run -- apk del .build-deps
acbuild --debug run -- apk del .gettext
acbuild --debug run -- mv /var/tmp/envsubst /usr/local/bin/

# forward request and error logs to docker log collector
acbuild --debug run -- ln -sf /dev/stdout /var/log/nginx/access.log
acbuild --debug run -- ln -sf /dev/stderr /var/log/nginx/error.log

# ================================================
# Port configuration for Nginx
# ================================================

# Add a port for http traffic over port 8080
acbuild --debug port add http tcp 8080
# Add a port for rtmp traffic over port 1935
acbuild --debug port add rtmp tcp 1935

# Add a mount point for files to serve
acbuild --debug copy nginx.conf /etc/nginx/nginx.conf

# Run nginx in the foreground
acbuild --debug set-exec -- /usr/sbin/nginx -g "daemon off;"

# Save the ACI
acbuild --debug write --overwrite xplex-nginx-rtmp-$VERSION.aci

# End the build
acbuild --debug end
