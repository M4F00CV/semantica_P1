#!/usr/bin/env bash
set -euo pipefail

BASE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE"

verde() { printf "\033[1;32m%s\033[0m\n" "$*"; }
azul()  { printf "\033[1;34m%s\033[0m\n" "$*"; }
rojo()  { printf "\033[1;31m%s\033[0m\n" "$*"; }

azul "→ 1/5: Validando XML (DTD + XSD)…"
if ! xmllint --noout --dtdvalid data/proyecto.dtd data/proyecto.xml; then
    rojo "✗ XML inválido contra DTD"; exit 1
fi
if ! xmllint --noout --schema data/proyecto.xsd data/proyecto.xml; then
    rojo "✗ XML inválido contra XSD"; exit 1
fi
verde "✓ XML válido."

azul ""
azul "→ 2/5: Regenerando vista XSLT…"
xsltproc --output out/proyecto.html xsl/proyecto.xsl data/proyecto.xml
verde "✓ out/proyecto.html regenerado."

azul ""
azul "→ 3/5: Verificando que no quede Python…"
PY_HITS=$(grep -rn "^[^#]*python3\|^[^#]*#!/usr/bin/env python\|import python\|from python" \
              scripts/ cgi-bin/ web/ \
              --exclude="entrega.sh" 2>/dev/null || true)
if [ -n "$PY_HITS" ]; then
    rojo "✗ Se encontraron referencias ejecutables a Python:"
    echo "$PY_HITS"
    exit 1
fi
verde "✓ Sin dependencias de Python."

azul ""
azul "→ 4/5: Empaquetando…"
FECHA=$(date +%Y%m%d)
ARCHIVO="entrega-proyecto-${FECHA}.zip"
rm -f "$ARCHIVO"
zip -rq "$ARCHIVO" \
    cgi-bin/ \
    data/ \
    out/ \
    scripts/ \
    web/ \
    xsl/ \
    README.md \
    -x "data/.backups/*" \
    -x "*.aux" "*.log" "*.out" "*.toc" \
    -x "*.zip"

verde "✓ Paquete creado: $ARCHIVO"

azul ""
azul "→ 5/5: Contenido del paquete:"
unzip -l "$ARCHIVO"

echo
verde "═══════════════════════════════════════════"
verde "  Entrega lista: $ARCHIVO"
verde "═══════════════════════════════════════════"
