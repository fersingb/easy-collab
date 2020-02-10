#!/bin/bash
if [[ $# -ne 2 ]] ; then
	echo "usage: ./start.sh DOMAIN IP"
	exit
fi

DOMAIN=$1
IP=$2


### BIND CONFIG ###

docker run -d --rm  \
	--name=easy-collab \
	-e PUID=$(id -u) \
	-e PGID=$(id -g) \
	-e DOMAIN=$DOMAIN \
	-e IP=$IP \
	-e STAGING=true \
	-e DEFAULT_DHPARAMS=true \
	-p 443:443 \
	-p 80:80 `#optional` \
	-p $IP:53:53 \
	-p $IP:53:53/udp \
	-v $(pwd)/data:/config \
	fersingb/easy-collab
