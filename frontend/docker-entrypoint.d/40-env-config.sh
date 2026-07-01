#!/bin/sh
set -eu

is_safe_url() {
  case "$1" in
    ''|*[!A-Za-z0-9:/._-]*) return 1 ;;
    *) return 0 ;;
  esac
}

authn_base_url="${AUTHN_BASE_URL:-http://localhost:5000}"
gallery_base_url="${GALLERY_BASE_URL:-http://localhost:8081}"

if ! is_safe_url "$authn_base_url"; then
  authn_base_url='http://localhost:5000'
fi

if ! is_safe_url "$gallery_base_url"; then
  gallery_base_url='http://localhost:8081'
fi

cat > /usr/share/nginx/html/config.js <<EOF
window.__APP_CONFIG__ = {
  AUTHN_BASE_URL: '${authn_base_url}',
  GALLERY_BASE_URL: '${gallery_base_url}'
}
EOF
