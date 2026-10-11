#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SERVICE="i2planding.service"
BINARY="$REPO_DIR/i2planding"
ROLLBACK="$REPO_DIR/i2planding.rollback"
NEW_BINARY="$REPO_DIR/.i2planding.new"
HEALTH_URL="http://127.0.0.1:5183/healthz"

if [[ $EUID -eq 0 ]]; then
    echo "Do not run this script as root."
    exit 1
fi

cd "$REPO_DIR"

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Working tree has uncommitted changes; refusing to deploy."
    git status --short
    exit 1
fi

echo "==> Updating source"
git pull --ff-only

echo "==> Building"
rm -f "$NEW_BINARY"
go build -trimpath -o "$NEW_BINARY" .

echo "==> Saving previous binary"
if [[ -f "$BINARY" ]]; then
    cp -a "$BINARY" "$ROLLBACK"
fi

echo "==> Installing new binary"
chmod 0755 "$NEW_BINARY"
mv -f "$NEW_BINARY" "$BINARY"

echo "==> Restarting $SERVICE"
sudo systemctl restart "$SERVICE"

echo "==> Waiting for health check"
for attempt in {1..10}; do
    if curl -fsS "$HEALTH_URL" >/dev/null; then
        echo "==> Deploy successful"
        echo "Commit: $(git rev-parse --short HEAD)"
        systemctl --no-pager --quiet is-active "$SERVICE"
        exit 0
    fi

    sleep 1
done

echo "ERROR: health check failed after deployment."
systemctl status "$SERVICE" --no-pager || true

echo "Previous binary preserved at:"
echo "  $ROLLBACK"
exit 1
