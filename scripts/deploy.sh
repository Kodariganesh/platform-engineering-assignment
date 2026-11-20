#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" != "0" ]]; then
    printf 'Run this deployment script as root, for example with sudo bash scripts/deploy.sh.\n' >&2
    exit 1
fi

trap 'printf "Deployment failed at line %s.\n" "$LINENO" >&2' ERR

app_user="platform-app"
app_dir="/opt/platform-app"
venv_python="$app_dir/.venv/bin/python"
health_url="http://127.0.0.1:8080/health"
unit_files=(
    systemd/platform-app.service
    systemd/platform-health.service
    systemd/platform-health.timer
)

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
for source_file in app/server.py requirements.txt scripts/health-check.sh "${unit_files[@]}"; do
    if [[ ! -f "$source_file" ]]; then
        printf 'Deployment source is missing: %s\n' "$source_file" >&2
        exit 1
    fi
done

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl python3 python3-venv

if ! getent group "$app_user" >/dev/null; then
    groupadd --system "$app_user"
fi
if ! id "$app_user" >/dev/null 2>&1; then
    useradd --system --gid "$app_user" --home-dir "$app_dir" \
        --no-create-home --shell /usr/sbin/nologin "$app_user"
fi

install -d -o root -g root -m 0755 "$app_dir" "$app_dir/app" "$app_dir/scripts"
if [[ ! -x "$venv_python" ]]; then
    python3 -m venv "$app_dir/.venv"
fi
"$venv_python" -m pip --disable-pip-version-check install -r requirements.txt

install -o root -g root -m 0644 app/server.py "$app_dir/app/server.py"
install -o root -g root -m 0755 scripts/health-check.sh "$app_dir/scripts/health-check.sh"
install -o root -g root -m 0644 "${unit_files[@]}" /etc/systemd/system/

systemctl daemon-reload
systemctl restart platform-app.service
curl --fail --silent --show-error --max-time 5 --retry 5 --retry-delay 1 \
    --retry-connrefused --noproxy '*' --output /dev/null "$health_url"
systemctl enable platform-app.service
systemctl enable --now platform-health.timer

printf 'Deployment complete. The app and health timer are enabled at boot.\n'
