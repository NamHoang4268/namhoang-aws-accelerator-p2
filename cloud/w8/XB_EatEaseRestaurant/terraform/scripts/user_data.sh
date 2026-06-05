#!/bin/bash
set -euo pipefail
exec > /var/log/user_data.log 2>&1

echo "=== [1/4] Update & install dependencies ==="
apt-get update -y
apt-get install -y nginx git curl

curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

echo "=== [2/4] Clone repo and get built frontend ==="
cd /tmp
git clone https://github.com/NamHoang4268/EatEaseRestaurant_System.git eatease

echo "=== [3/4] Copy built frontend to nginx webroot ==="

if [ -d "/tmp/eatease/client/dist" ]; then
  cp -r /tmp/eatease/client/dist/* /var/www/html/
  echo "Frontend copied from client/dist"
else
  echo "client/dist not found — running build"
  cd /tmp/eatease/client
  npm install
  NODE_OPTIONS="--max-old-space-size=3072" npm run build
  cp -r dist/* /var/www/html/
fi

echo "=== [4/4] Configure nginx for React SPA ==="
cat > /etc/nginx/sites-available/default << 'NGINX_CONF'
server {
    listen 80;
    server_name _;
    root /var/www/html;
    index index.html;

    # React Router — serve index.html for all routes
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
NGINX_CONF

nginx -t
systemctl restart nginx
systemctl enable nginx

echo "=== Bootstrap complete ==="
echo "App running at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
