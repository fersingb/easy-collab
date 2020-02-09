# easy-collab

## How to use
```
git clone https://github.com/fersingb/easy-collab.git
cd easy-collab
./start <YOUR DOMAIN> <YOUR PUBLIC IP>
```

This will start a Bind9 DNS server that will answer all requests made for the subdomains of `<YOUR DOMAIN>`. The answer's `A` record will be `<YOUR PUBLIC IP>`.

Requests to your DNS servers are logged in `./logfile`

The script also starts a nginx server that is configured to use letsencrypt certificates. On start, certbot will request a wildcard certificate for `<YOUR DOMAIN>`, using the Bind9 server for DNS validation. 

After that you'll be able to server content from `./nginx/www/` on port 443 with a valid certificate. Plain HTTP on port 80 works as well.

The nginx server also comes with support for PHP. Files in `./nginx/www/` that end with `.php` will be interpreted.

The nginx logs are in `./nginx/logs/nginx/`

Note: The first start might take some time and you'll see a high CPU usage during that time. This is because of the dhparams generation and it will only happen on the first start as long as you don't delete `./nginx/`

## Requirements
- Docker
- Your machine is configured as the NS for your domain (or subdomain)

## Credits
This project is based on those 2 projects:
- https://github.com/linuxserver/docker-letsencrypt
- https://github.com/andrewnk/docker-alpine-nginx-modsec
