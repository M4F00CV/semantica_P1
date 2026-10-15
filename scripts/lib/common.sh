#!/usr/bin/env bash
# Utilidades compartidas por el CLI

# ---- Rutas ----
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$COMMON_DIR/../.." && pwd)"
XML="$PROJECT_ROOT/data/proyecto.xml"
DTD="$PROJECT_ROOT/data/proyecto.dtd"
XSD="$PROJECT_ROOT/data/proyecto.xsd"
BACKUP_DIR="$PROJECT_ROOT/data/.backups"

# ---- Colores ----
rojo()    { printf "\033[1;31m%s\033[0m\n" "$*"; }
verde()   { printf "\033[1;32m%s\033[0m\n" "$*"; }
azul()    { printf "\033[1;34m%s\033[0m\n" "$*"; }
amarillo(){ printf "\033[1;33m%s\033[0m\n" "$*"; }
gris()    { printf "\033[0;90m%s\033[0m\n" "$*"; }

die()  { rojo "✗ $*" >&2; exit 1; }
info() { azul "→ $*"; }
ok()   { verde "✓ $*"; }
warn() { amarillo "! $*"; }

# ---- Herramientas ----
require_tools() {
    command -v xmlstarlet >/dev/null 2>&1 || die "Falta xmlstarlet. Instálalo: sudo apt install xmlstarlet"
    command -v xmllint    >/dev/null 2>&1 || die "Falta xmllint (libxml2-utils)."
    [ -f "$XML" ] || die "No existe $XML"
}

# ---- Utilidades ----
hoy() { date +%Y-%m-%d; }

xml_escape() {
    printf '%s' "$1" \
        | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'
}

# Genera el siguiente ID con prefijo + 3 dígitos (p001, pr001, pa001)
# Uso: next_id "/datos/personas/persona" "p"
next_id() {
    local path="$1" prefix="$2"
    local max_num=0
    local ids
    ids=$(xmlstarlet sel -t -v "$path/@id" "$XML" 2>/dev/null | grep -oE "^${prefix}[0-9]+$" | sed "s/^${prefix}//" | sort -n || true)
    if [ -n "$ids" ]; then
        max_num=$(echo "$ids" | tail -1)
    fi
    printf "%s%03d" "$prefix" "$((10#$max_num + 1))"
}

existe_persona() { [ "$(xmlstarlet sel -t -v "count(/datos/personas/persona[@id='$1'])" "$XML")" -gt 0 ]; }
existe_proyecto() { [ "$(xmlstarlet sel -t -v "count(/datos/proyectos/proyecto[@id='$1'])" "$XML")" -gt 0 ]; }
estado_persona() { xmlstarlet sel -t -v "/datos/personas/persona[@id='$1']/@estado" "$XML"; }
estado_proyecto() { xmlstarlet sel -t -v "/datos/proyectos/proyecto[@id='$1']/@estado" "$XML"; }

# Backup
backup() {
    mkdir -p "$BACKUP_DIR"
    local ts f
    ts="$(date +%Y%m%d-%H%M%S)"
    f="$BACKUP_DIR/proyecto-$ts.xml"
    cp "$XML" "$f"
    printf '%s' "$f"
}

# Validación silenciosa
validar_estructura() {
    xmllint --noout "$XML" 2>/dev/null || return 1
    xmllint --noout --dtdvalid "$DTD" "$XML" 2>/dev/null || return 1
    xmllint --noout --schema "$XSD" "$XML" 2>/dev/null || return 1
    return 0
}

# Ejecuta una función con backup + rollback automático
# Uso: with_backup _mi_funcion arg1 arg2
with_backup() {
    local bk
    bk=$(backup)
    info "Backup: $(basename "$bk")"
    if ! "$@"; then
        cp "$bk" "$XML"
        die "Operación falló. XML restaurado."
    fi
    if ! validar_estructura; then
        cp "$bk" "$XML"
        die "XML no válido tras la operación. Restaurado desde backup."
    fi
    ok "Operación exitosa. XML válido."
}

# Inserta un bloque XML antes de un patrón (por defecto una etiqueta de cierre)
# Uso: insert_before "</personas>" "$bloque"
insert_before() {
    local pattern="$1" block="$2"
    local tmp="${XML}.tmp.$$" blk="${XML}.blk.$$"
    printf '%s\n' "$block" > "$blk"
    awk -v pat="$pattern" -v blkfile="$blk" '
        $0 ~ pat && !done {
            while ((getline line < blkfile) > 0) print line
            close(blkfile)
            done=1
        }
        { print }
    ' "$XML" > "$tmp"
    mv "$tmp" "$XML"
    rm -f "$blk"
}

# Añade un <evento> al historial de una persona o proyecto
# Uso: add_evento "/datos/personas/persona[@id='p001']/historial" "baja" "motivo" "fecha"
add_evento() {
    local hist_path="$1" tipo="$2" motivo="${3:-}" fecha="${4:-$(hoy)}"
    local args=(
        -s "$hist_path" -t elem -n evento -v ""
        -i "${hist_path}/evento[last()]" -t attr -n tipo   -v "$tipo"
        -i "${hist_path}/evento[last()]" -t attr -n fecha  -v "$fecha"
    )
    if [ -n "$motivo" ]; then
        args+=(-i "${hist_path}/evento[last()]" -t attr -n motivo -v "$motivo")
    fi
    xmlstarlet ed -L "${args[@]}" "$XML"
}