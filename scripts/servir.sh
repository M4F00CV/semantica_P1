#!/usr/bin/env bash
set -euo pipefail

BASE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE"

PORT="${1:-8000}"

echo "→ Servidor busybox httpd en http://localhost:$PORT/"
echo "   SPA:        http://localhost:$PORT/web/proyecto.html"
echo "   XML:        http://localhost:$PORT/data/proyecto.xml"
echo "   POST save:  http://localhost:$PORT/cgi-bin/save"
echo "   Ctrl+C para detener."

# -f: en primer plano (necesario para Ctrl+C)
# -v: verbose (muestra cada petición)
# -p: puerto
# -h: docroot (raíz del proyecto)
# CGI por defecto vive en <docroot>/cgi-bin/
exec busybox httpd -f -v -p "$PORT" -h "$BASE"