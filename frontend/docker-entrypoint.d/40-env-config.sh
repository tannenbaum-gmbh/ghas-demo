#!/bin/sh
set -eu

escape_js_string() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g"
}

authn_base_url="$(escape_js_string "${AUTHN_BASE_URL:-http://localhost:5000}")"
gallery_base_url="$(escape_js_string "${GALLERY_BASE_URL:-http://localhost:8081}")"

cat > /usr/share/nginx/html/config.js <<EOF
window.__APP_CONFIG__ = {
  AUTHN_BASE_URL: '${authn_base_url}',
  GALLERY_BASE_URL: '${gallery_base_url}'
}
EOF
