#!/usr/bin/env bash
set -euo pipefail

BASE="$(cd "$(dirname "$0")/.." && pwd)"
XML="$BASE/data/proyecto.xml"
DTD="$BASE/data/proyecto.dtd"
XSD="$BASE/data/proyecto.xsd"
XSL="$BASE/xsl/proyecto.xsl"
OUT="$BASE/out/proyecto.html"
DEBOUNCE=1     # segundos

verde() { printf "\033[1;32m%s\033[0m\n" "$*"; }
rojo()  { printf "\033[1;31m%s\033[0m\n" "$*"; }
azul()  { printf "\033[1;34m%s\033[0m\n" "$*"; }

regenerar() {
    if ! xmllint --noout --dtdvalid "$DTD" "$XML" 2>/dev/null; then
        rojo "✗ XML inválido contra DTD; no regenero."
        return
    fi
    if ! xmllint --noout --schema "$XSD" "$XML" 2>/dev/null; then
        rojo "✗ XML inválido contra XSD; no regenero."
        return
    fi
    xsltproc --output "$OUT" "$XSL" "$XML"
    verde "✓ out/proyecto.html regenerado ($(date +%H:%M:%S))"
}

mkdir -p "$(dirname "$OUT")"

if command -v inotifywait >/dev/null 2>&1; then
    azul "→ Vigilando $XML con inotifywait (Ctrl+C para detener)…"
    # Primera generación por si acaso
    regenerar
    while inotifywait -q -e close_write,move,create "$XML" >/dev/null 2>&1; do
        sleep "$DEBOUNCE"
        regenerar
    done
else
    azul "→ inotifywait no disponible; usando polling cada ${DEBOUNCE}s (Ctrl+C para detener)…"
    LAST=""
    while true; do
        CUR=$(stat -c %Y "$XML" 2>/dev/null || stat -f %m "$XML" 2>/dev/null || echo 0)
        if [ "$CUR" != "$LAST" ]; then
            LAST="$CUR"
            sleep "$DEBOUNCE"
            regenerar
        fi
        sleep "$DEBOUNCE"
    done
fi