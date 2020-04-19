# server {
#     listen 80;
#     listen [::]:80;

#     server_name admin.kahvipatel.com;
#     root /var/www/admin.kahvipatel.com/system/nginx-root; # Used for acme.sh SSL verification (https://acme.sh)

#     location / {
#         proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#         proxy_set_header X-Forwarded-Proto $scheme;
#         proxy_set_header X-Real-IP $remote_addr;
#         proxy_set_header Host $http_host;
#         proxy_pass http://127.0.0.1:2368;
        
#     }

#     location ~ /.well-known {
#         allow all;
#     }

#     client_max_body_size 50m;
# }

# server {
# 	root /var/www/admin.kahvipatel.com/current;
# 	index index.js;

# 	server_name www.admin.kahvipatel.com admin.kahvipatel.com;

# 	location / {
#         proxy_set_header X-Real-IP 142.93.152.73;
#         proxy_set_header X-Forwarded-Host: admin.kahvipatel.com;
#         proxy_set_header X-Forwarded-Proto: https;

#         proxy_pass http://localhost:2368;
#         # proxy_redirect off;
#     }

#     listen 443 ssl; # managed by Certbot
#     ssl_certificate /etc/letsencrypt/live/admin.kahvipatel.com/fullchain.pem; # managed by Certbot
#     ssl_certificate_key /etc/letsencrypt/live/admin.kahvipatel.com/privkey.pem; # managed by Certbot
#     include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
#     ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

# 	# rewrite ^/$ https://www.admin.kahvipatel.com/ghost permanent;
# }


# Virtual Host configuration for example.com
#
# You can move that to a different file under sites-available/ and symlink that
# to sites-enabled/ to enable it.
#
#server {
#	listen 80;
#	listen [::]:80;
#
#	server_name example.com;
#
#	root /var/www/example.com;
#	index index.html;
#
#	location / {
#		try_files $uri $uri/ =404;
#	}
#}
# server {
	
#    if ($host = www.admin.kahvipatel.com) {
# 		return 301 https://$host$request_uri;
#    } # managed by Certbot

#    if ($host = admin.kahvipatel.com) {
# 		return 301 https://$host$request_uri;
#    } # managed by Certbot

# 	server_name www.admin.kahvipatel.com admin.kahvipatel.com;
#    listen 80;
#    return 404; # managed by Certbot

# }

