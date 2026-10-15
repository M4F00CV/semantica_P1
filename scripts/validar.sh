#!/usr/bin/env bash
# Valida proyecto.xml contra DTD y XSD
set -euo pipefail

BASE="$(cd "$(dirname "$0")/.." && pwd)"
XML="$BASE/data/proyecto.xml"
DTD="$BASE/data/proyecto.dtd"
XSD="$BASE/data/proyecto.xsd"

azul()  { printf "\033[1;34m%s\033[0m\n" "$1"; }
verde() { printf "\033[1;32m%s\033[0m\n" "$1"; }
rojo()  { printf "\033[1;31m%s\033[0m\n" "$1"; }

azul "→ 1/3: Verificando que el XML esté bien formado…"
if xmllint --noout "$XML"; then verde "   XML bien formado."; fi

azul "→ 2/3: Validando contra DTD…"
if xmllint --noout --dtdvalid "$DTD" "$XML"; then
    verde "   DTD OK."
else
    rojo "   DTD falló."
fi

azul "→ 3/3: Validando contra XSD…"
if xmllint --noout --schema "$XSD" "$XML"; then
    verde "   XSD OK."
else
    rojo "   XSD falló."
fi

verde "Validación terminada."