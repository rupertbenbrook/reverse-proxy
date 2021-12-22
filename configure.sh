#!/bin/sh
mkdir -p /etc/ssl/certs/nginx
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -subj "/C=$PROXY_CERT_COUNTRY/ST=$PROXY_CERT_STATE/L=$PROXY_CERT_LOCATION/O=$PROXY_CERT_ORGANIZATION/OU=$PROXY_CERT_DEPT/CN=$PROXY_HOST" -keyout /etc/ssl/certs/nginx/ssl.key -out /etc/ssl/certs/nginx/ssl.crt

mkdir -p /var/www/html
cat << EOF > /var/www/html/origin-not-found.html
<html>
<head><title>Proxy Origin Not Found</title></head>
<body>
<h1>Proxy Origin Not Found</h1>
<p><a href="${PROXY_ORIGIN_PROTOCOL}://${PROXY_ORIGIN_HOST}">${PROXY_ORIGIN_PROTOCOL}://${PROXY_ORIGIN_HOST}</a></p>
</body>
</html>
EOF

cat << EOF > /etc/nginx/conf.d/default.conf
server {
    listen 80;
    listen 443 ssl http2;
    server_name ${PROXY_HOST};

    ssl_certificate /etc/ssl/certs/nginx/ssl.crt;
    ssl_certificate_key /etc/ssl/certs/nginx/ssl.key;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers 'ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHAECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS';
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass ${PROXY_ORIGIN_PROTOCOL}://${PROXY_ORIGIN_HOST};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host \$proxy_host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_busy_buffers_size 512k;
        proxy_buffers 4 512k;
        proxy_buffer_size 256k;
    }

    access_log /dev/stdout;
    error_log /dev/stderr;
}

server {
    listen 80 default_server;

    server_name _;
    root /var/www/html;

    charset UTF-8;

    error_page 404 /origin-not-found.html;
    location = /origin-not-found.html {
        allow all;
    }
    location / {
        return 404;
    }

    access_log /dev/stdout;
    error_log /dev/stderr;
}
EOF
cat /etc/nginx/conf.d/default.conf
