#!/bin/bash
if [[ $# -ne 2 ]] ; then
	echo "usage: ./start.sh DOMAIN IP"
	exit
fi

DOMAIN=$1
IP=$2


### BIND CONFIG ###

rm -rf conf/
mkdir conf/
cat << EOF > conf/myzone.db
\$TTL 1
\$ORIGIN $DOMAIN.

@       IN      SOA     $DOMAIN.      root.$DOMAIN. (
                        2020010901      ; serial number YYMMDDNN
                        28800           ; Refresh
                        7200            ; Retry
                        604800          ; Expire
                        1               ; Min TTL
                        )
        IN      NS      $IP
*       IN      A       $IP

; \$ORIGIN a.$DOMAIN.
; 
; *       IN      A       127.0.0.1
EOF

cat << EOF > conf/named.conf
options {
        directory "/var/bind";
        // Configure the IPs to listen on here.
        listen-on { any; };
        listen-on-v6 { none; };
        // If you want to allow only specific hosts to use the DNS server:
        allow-query { any; };
        allow-transfer { none;};
        pid-file "/var/run/named/named.pid";
        allow-recursion { none; };
        recursion no;
};

logging {
        channel bind_log {
                file "/var/log/named/named.log" versions 3 size 5m;
                severity info;
                print-category yes;
                print-severity yes;
                print-time yes;
        };
        category default { bind_log; };
        category update { bind_log; };
        category update-security { bind_log; };
        category security { bind_log; };
        category queries { bind_log; };
        category lame-servers { null; };
};

zone "$DOMAIN" IN {
        type master;
        file "/etc/bind/master/myzone.db";
        update-policy {
                  grant keyname. zonesub TXT;
        };

};
EOF

RFC2136_CONF=$(docker run --rm -it resystit/bind9 ddns-confgen -a HMAC-SHA512 -k keyname. -q)
echo "$RFC2136_CONF" >> conf/named.conf

touch logfile
chmod 777 logfile


docker run -d --rm --name bind9 -p $IP:53:53 -p $IP:53:53/udp -v $(pwd)/logfile:/var/log/named/named.log -v $(pwd)/conf/named.conf:/etc/bind/named.conf -v  $(pwd)/conf/myzone.db:/etc/bind/master/myzone.db resystit/bind9:latest  /usr/sbin/named -c /etc/bind/named.conf -u named -f

docker exec -it bind9 chmod 775 /etc/bind/ -R
docker exec -it bind9 chown root:named /etc/bind/ -R


### NGINX / LETSENCRYPT ###
RFC2136_SECRET=$(echo "$RFC2136_CONF"|grep secret|cut -d '"' -f2)
mkdir -p nginx/dns-conf/
cat << EOF > nginx/dns-conf/rfc2136.ini
dns_rfc2136_server = $IP
# TSIG key name
dns_rfc2136_name = keyname.
# TSIG key secret
dns_rfc2136_secret = $RFC2136_SECRET
# TSIG key algorithm
dns_rfc2136_algorithm = HMAC-SHA512
EOF

mkdir -p nginx/fail2ban
cat << EOF > nginx/fail2ban/jail.local
[DEFAULT]
bantime  = 600
findtime  = 600
maxretry = 5

[ssh]
enabled = false
EOF


mkdir -p nginx/nginx/site-confs/
cat << EOF > nginx/nginx/site-confs/default
server {
        listen 80 default_server;
        listen [::]:80 default_server;
        listen 443 ssl http2 default_server;
        listen [::]:443 ssl http2 default_server;
        root /config/www;
        index index.html index.htm index.php;
        server_name _;
        include /config/nginx/proxy-confs/*.subfolder.conf;
        include /config/nginx/ssl.conf;
        client_max_body_size 0;
        location / {
                try_files \$uri $uri/ /index.html /index.php?\$args =404;
        }

        location ~ \.php$ {
                fastcgi_split_path_info ^(.+\.php)(/.+)$;
                fastcgi_pass 127.0.0.1:9000;
                fastcgi_index index.php;
                include /etc/nginx/fastcgi_params;
        }
}
EOF
docker run -d --rm  \
	--name=nginx \
	-e PUID=$(id -u) \
	-e PGID=$(id -g) \
	-e TZ=UTC \
	-e URL=$DOMAIN \
	-e SUBDOMAINS=wildcard \
	-e VALIDATION=dns \
	-e DNSPLUGIN=rfc2136 \
	-p 443:443 \
	-p 80:80 `#optional` \
	-v $(pwd)/nginx:/config \
	linuxserver/letsencrypt
