#!/bin/sh
set -eu

cat > /usr/share/nginx/html/config.js <<EOF
window.__APP_CONFIG__ = {
  AUTHN_BASE_URL: '${AUTHN_BASE_URL:-http://localhost:5000}',
  GALLERY_BASE_URL: '${GALLERY_BASE_URL:-http://localhost:8081}'
}
EOF
