#!/usr/bin/env bash
# Genera vistas HTML a partir del XML usando XSLT
set -euo pipefail

BASE="$(cd "$(dirname "$0")/.." && pwd)"
XML="$BASE/data/proyecto.xml"
XSL="$BASE/xsl/proyecto.xsl"
OUT="$BASE/out"

mkdir -p "$OUT"

echo "→ Transformando $XML con $XSL…"
xsltproc --output "$OUT/proyecto.html" "$XSL" "$XML"

echo "→ Resultado: $OUT/proyecto.html"
echo "   Abre con: xdg-open $OUT/proyecto.html"