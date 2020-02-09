FROM lsiobase/nginx:3.11 as build_modsecurity

RUN apk add \
        gcc \
        libc-dev \
        make \
        openssl-dev \
        pcre-dev \
        zlib-dev \
        linux-headers \
        curl \
        gnupg \
        libxslt-dev \
        gd-dev \
        perl-dev \
        pcre-dev \
        libxml2-dev \
        git \
        libtool \
        automake \
        autoconf \
        g++ \
        flex \
        bison \
        yajl-dev \
    # Add runtime dependencies that should not be removed
    && apk add --no-cache \
        geoip \
        geoip-dev \
        yajl \
        libstdc++ \
        git \
        sed \
        libmaxminddb-dev

WORKDIR /opt/ModSecurity

RUN echo "Installing ModSec Library" && \
    git clone -b v3.0.4 --single-branch https://github.com/SpiderLabs/ModSecurity . && \
    git submodule init && \
    git submodule update && \
    ./build.sh && \
    ./configure && make && make install

WORKDIR /opt

RUN echo 'Installing ModSec - Nginx connector' && \
    git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git && \
    wget "http://nginx.org/download/nginx-$(nginx -v 2>&1|cut -d/ -f2).tar.gz" && \
    tar zxvf "nginx-$(nginx -v 2>&1|cut -d/ -f2).tar.gz" && \
    mv "nginx-$(nginx -v 2>&1|cut -d/ -f2)" nginx-src

WORKDIR /opt/nginx-src

RUN echo "Running ./configure $(nginx -V 2>&1|grep configure|cut -d: -f2-|sed -E 's/--add-dynamic-module=[^ ]+//g') --add-dynamic-module=../ModSecurity-nginx"

RUN ./configure $(nginx -V 2>&1|grep configure|cut -d: -f2-|sed -E 's/--add-dynamic-module=[^ ]+//g') --add-dynamic-module=../ModSecurity-nginx  && \
    make modules && \
    cp objs/ngx_http_modsecurity_module.so /usr/lib/nginx/modules/ && \
    rm -f /usr/local/modsecurity/lib/libmodsecurity.a /usr/local/modsecurity/lib/libmodsecurity.la


FROM lsiobase/nginx:3.11

# set version label
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="fersingb"

# environment settings
ENV DHLEVEL=2048 ONLY_SUBDOMAINS=false AWS_CONFIG_FILE=/config/dns-conf/route53.ini
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2

RUN apk upgrade --no-cache \
      && apk add --no-cache \
             yajl \
	     geoip-dev \
	     geoip \
             libstdc++ \
             libmaxminddb-dev \
             tzdata \
      && chown -R nginx:nginx /etc/nginx
RUN \
 echo "**** install build packages ****" && \
 apk add --no-cache --virtual=build-dependencies \
	g++ \
	gcc \
	libffi-dev \
	openssl-dev \
	python3-dev && \
 echo "**** install runtime packages ****" && \
 apk add --no-cache --upgrade \
 	bind \
	curl \
	gnupg \
	memcached \
        geoip \
        geoip-dev \
        yajl \
        libstdc++ \
        git \
        sed \
        libmaxminddb-dev \
	tzdata \
	nginx \
	nginx-mod-http-echo \
	nginx-mod-http-fancyindex \
	nginx-mod-http-geoip2 \
	nginx-mod-http-headers-more \
	nginx-mod-http-image-filter \
	nginx-mod-http-lua \
	nginx-mod-http-lua-upstream \
	nginx-mod-http-nchan \
	nginx-mod-http-perl \
	nginx-mod-http-redis2 \
	nginx-mod-http-set-misc \
	nginx-mod-http-upload-progress \
	nginx-mod-http-xslt-filter \
	nginx-mod-mail \
	nginx-mod-rtmp \
	nginx-mod-stream \
	nginx-mod-stream-geoip2 \
	nginx-vim \
	php7-bcmath \
	php7-bz2 \
	php7-ctype \
	php7-curl \
	php7-dom \
	php7-exif \
	php7-ftp \
	php7-gd \
	php7-iconv \
	php7-imap \
	php7-intl \
	php7-ldap \
	php7-mcrypt \
	php7-memcached \
	php7-mysqli \
	php7-mysqlnd \
	php7-opcache \
	php7-pdo_mysql \
	php7-pdo_odbc \
	php7-pdo_pgsql \
	php7-pdo_sqlite \
	php7-pear \
	php7-pecl-apcu \
	php7-pecl-imagick \
	php7-pecl-redis \
	php7-pgsql \
	php7-phar \
	php7-posix \
	php7-soap \
	php7-sockets \
	php7-sqlite3 \
	php7-tokenizer \
	php7-xml \
	php7-xmlreader \
	php7-xmlrpc \
	php7-zip \
	py3-cryptography \
	py3-future \
	py3-pip && \
 echo "**** install certbot plugins ****" && \
 if [ -z ${CERTBOT_VERSION+x} ]; then \
        CERTBOT="certbot"; \
 else \
        CERTBOT="certbot==${CERTBOT_VERSION}"; \
 fi && \
 pip3 install -U \
	pip && \
 pip3 install -U \
	${CERTBOT} \
	certbot-dns-cloudflare \
	certbot-dns-cloudxns \
	certbot-dns-cpanel \
	certbot-dns-digitalocean \
	certbot-dns-dnsimple \
	certbot-dns-dnsmadeeasy \
	certbot-dns-domeneshop \
	certbot-dns-google \
	certbot-dns-inwx \
	certbot-dns-linode \
	certbot-dns-luadns \
	certbot-dns-nsone \
	certbot-dns-ovh \
	certbot-dns-rfc2136 \
	certbot-dns-route53 \
	certbot-dns-transip \
	certbot-plugin-gandi \
	cryptography \
	requests && \
 echo "**** configure nginx ****" && \
 rm -f /etc/nginx/conf.d/default.conf && \
 echo "**** cleanup ****" && \
 apk del --purge \
	build-dependencies && \
 for cleanfiles in *.pyc *.pyo; \
	do \
	find /usr/lib/python3.*  -iname "${cleanfiles}" -exec rm -f '{}' + \
	; done && \
 rm -rf \
	/tmp/* \
	/root/.cache

# Copy the modsec files from build container
RUN mkdir /etc/nginx/modsec && \
    rm -fr /etc/nginx/conf.d/ && \
    rm -fr /etc/nginx/nginx.conf

# Copy nginx libs from the intermediate container
COPY --from=build_modsecurity /usr/local/modsecurity /usr/local/modsecurity
COPY --from=build_modsecurity /usr/lib/nginx/modules/ngx_http_modsecurity_module.so /usr/lib/nginx/modules/
RUN mkdir -p /etc/nginx/modsec && \
	echo 'Include "/etc/nginx/modsec/modsecurity.conf"' > /etc/nginx/modsec/main.conf && \ 
	echo -e "SecAuditEngine On\nSecAuditLogParts ABCDFE\nSecAuditLogType Serial\nSecAuditLog /config/log/nginx/modsec_audit.log" > /etc/nginx/modsec/modsecurity.conf && \
	echo "load_module modules/ngx_http_modsecurity_module.so;" > /etc/nginx/modules/modsecurity.conf

RUN chown -R nginx:nginx /etc/nginx
# add local files
COPY root/ /
