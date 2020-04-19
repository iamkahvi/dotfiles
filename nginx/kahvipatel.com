server {

	gzip on;
	gzip_types application/javascript;

	root /var/www/kahvipatel.com/site-build;
	index index.html index.htm index.nginx-debian.html;

	server_name kahvipatel.com www.kahvipatel.com;

	#location / {
	#		proxy_pass http://localhost:4000/;
	#}

	location ~* \.(js|png)$ {
		expires 100d;
		add_header Cache-Control "public, no-transform";
	}

    listen [::]:443 ssl ipv6only=on; # managed by Certbot
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/kahvipatel.com/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/kahvipatel.com/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot


}
server {
	if ($host = www.kahvipatel.com) {
		return 301 https://$host$request_uri;
	} # managed by Certbot


	if ($host = kahvipatel.com) {
		return 301 https://$host$request_uri;
	} # managed by Certbot


		listen 80;
		listen [::]:80;

		server_name kahvipatel.com www.kahvipatel.com;
	return 404; # managed by Certbot
}
