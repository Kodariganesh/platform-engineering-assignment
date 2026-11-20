#!/usr/bin/env bash
set -euo pipefail

health_url="http://127.0.0.1:8080/health"
app_service="platform-app.service"

if http_status="$(curl --silent --show-error --max-time 5 --noproxy '*' \
    --output /dev/null --write-out '%{http_code}' "$health_url")" \
    && [[ "$http_status" == "200" ]]; then
    exit 0
fi

printf 'Health check failed for %s (HTTP %s). Restarting %s.\n' \
    "$health_url" "${http_status:-unknown}" "$app_service" >&2
systemctl restart "$app_service"
