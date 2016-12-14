#!/bin/sh

set -ex

NGINX_VERSION=$1
NGINX_RTMP_MODULE_VERSION=$2
NGINX_RTMP_MODULE_PATH="/opt/mod"

GPG_KEYS="B0F4253373F8F6F510D42178520A9993A1C052F8"
CONFIG="\
		--prefix=/etc/nginx \
		--sbin-path=/usr/sbin/nginx \
		--modules-path=/usr/lib/nginx/modules \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/var/log/nginx/error.log \
		--http-log-path=/var/log/nginx/access.log \
		--pid-path=/var/run/nginx.pid \
		--lock-path=/var/run/nginx.lock \
		--http-client-body-temp-path=/var/cache/nginx/client_temp \
		--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
		--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
		--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
		--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
		--user=nginx \
		--group=nginx \
        --add-module=${NGINX_RTMP_MODULE_PATH}/nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}
		--with-http_ssl_module
		--with-http_v2_module \
		--with-ipv6"


gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEYS"
gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz
rm -r nginx.tar.gz.asc

mkdir -p /usr/src
tar -zxC /usr/src -f nginx.tar.gz
rm nginx.tar.gz

mkdir -p ${NGINX_RTMP_MODULE_PATH}
tar -zxC ${NGINX_RTMP_MODULE_PATH} -f nginx-rtmp-module.tar.gz

cd /usr/src/nginx-$NGINX_VERSION
./configure $CONFIG
make -j$(getconf _NPROCESSORS_ONLN)
make install

rm -rf /etc/nginx/html/
mkdir /etc/nginx/conf.d/
ln -s ../../usr/lib/nginx/modules /etc/nginx/modules
strip /usr/sbin/nginx
rm -rf /usr/src/nginx-$NGINX_VERSION
