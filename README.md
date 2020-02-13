# easy-collab

## Description

This image will start a nginx server with letsencrypt support and a bind9 DNS server. It's purpose is to provide features similar to Burp Collaborator

## How to run it

Use the provided start.sh script in this repository, or run this command:

```bash
docker run -d \
        --name=easy-collab \
        -e PUID=$(id -u) \
        -e PGID=$(id -g) \
        -e DOMAIN=$DOMAIN \
        -e IP=$IP \
        -e STAGING=false \
        -e DEFAULT_DHPARAMS=true \
        -p 443:443 \
        -p 80:80 `#optional` \
        -p $IP:53:53 \
        -p $IP:53:53/udp \
        -v $(pwd)/data:/config \
        --restart unless-stopped \
        fersingb/easy-collab
```

- **DOMAIN** is the domain your machine is the NS for, BIND will answer requests for this domain and a wildcard Letsencrypt certificate will be generated for it.
- **IP** is your public IP
- **STAGING** do you want to use Letsencrypt's Staging environment. Should be false unless you're testing/debugging. If it's set to true then browsers won't trust the certificate
- **DEFAULT_DHPARAMS** set it to true if you want to use the provided dhparams file. This will save some time on first start. If you want to generate your own dhparams file then set it to false
- `-v $(pwd)/data:/config` the directory that will contain the www root, the log files, etc.

Here are some files/dir you might be interested in:
- `./data/www`: nginx root dir
- `./data/log/named/named.log`: DNS logs
- `./data/log/nginx/access.log`: nginx access logs
- `./data/log/nginx/modsec_audit.log`: nginx full request-response logs (modsecurity audit logs)

## Requirements
- Docker
- Your machine is configured as the NS for your domain (or subdomain):

        <subdomain>           60 IN NS     <my-machine-name>.domain.
        <my-machine-name>     60 IN A      <my-machine-ip>

## Credits
This project is based on those 2 projects:
- https://github.com/linuxserver/docker-letsencrypt
- https://github.com/andrewnk/docker-alpine-nginx-modsec
