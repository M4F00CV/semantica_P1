#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"
require_tools

CMD="${1:-ayuda}"
shift || true

# ============================================================
# AYUDA
# ============================================================
cmd_ayuda() {
    cat <<'EOF'
CLI de gestión de personas y proyectos

USO:  ./scripts/cli.sh <comando> [opciones]

PERSONAS
  persona-listar
  persona-ver            --id p001
  persona-crear          --nombre X --apellidos Y --email Z [--telefono T] [--departamento D]
  persona-editar         --id p001 [--nombre X] [--apellidos Y] [--email Z] [--telefono T] [--departamento D]
  persona-baja           --id p001 --motivo "Renuncia"
  persona-reactivar      --id p001

PROYECTOS
  proyecto-listar
  proyecto-ver           --id pr001
  proyecto-crear         --nombre X --descripcion D --titular p001
                         [--inicio YYYY-MM-DD] [--fin YYYY-MM-DD] [--monto N] [--moneda USD]
  proyecto-editar        --id pr001 [--nombre X] [--descripcion D] [--inicio F] [--fin F] [--monto N] [--moneda M]
  proyecto-reasignar     --id pr001 --nuevo p002
  proyecto-cerrar        --id pr001 --motivo "Entrega"
  proyecto-cancelar      --id pr001 --motivo "Cambio"

PARTICIPACIONES
  participacion-agregar  --persona p001 --proyecto pr001 [--rol miembro|observador]
  participacion-rol      --id pa001 --rol miembro|observador
  participacion-salir    --id pa001 [--motivo "Fin"]

OTROS
  validar                Valida el XML contra DTD y XSD
  ayuda                  Muestra esta ayuda
EOF
}

# ============================================================
# PARSEO SIMPLE DE --clave valor
# ============================================================
declare -A ARGS
parse_args() {
    ARGS=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --*) ARGS["${1#--}"]="${2:-}"; shift 2 ;;
            *) die "Argumento inesperado: $1" ;;
        esac
    done
}
need() { [ -n "${ARGS[$1]:-}" ] || die "Falta --$1"; }

# ============================================================
# VALIDAR
# ============================================================
cmd_validar() {
    info "Validando $XML…"
    validar_estructura && ok "XML válido (DTD + XSD)."
}

# ============================================================
# PERSONAS
# ============================================================
cmd_persona_listar() {
    printf "%-5s  %-32s  %-32s  %-8s\n" "ID" "NOMBRE COMPLETO" "EMAIL" "ESTADO"
    printf "%-5s  %-32s  %-32s  %-8s\n" "-----" "--------------------------------" "--------------------------------" "--------"
    xmlstarlet sel -t -m "/datos/personas/persona" \
        -v "@id" -o "|" \
        -v "concat(nombre,' ',apellidos)" -o "|" \
        -v "email" -o "|" \
        -v "@estado" -n "$XML" \
      | while IFS='|' read -r id nom eml est; do
            printf "%-5s  %-32s  %-32s  %-8s\n" "$id" "$nom" "$eml" "$est"
        done
}

cmd_persona_ver() {
    parse_args "$@"
    need id
    existe_persona "${ARGS[id]}" || die "No existe la persona ${ARGS[id]}"
    xmlstarlet sel -t -m "/datos/personas/persona[@id='${ARGS[id]}']" \
        -o "ID:            " -v "@id" -n \
        -o "Estado:        " -v "@estado" -n \
        -o "Nombre:        " -v "nombre" -n \
        -o "Apellidos:     " -v "apellidos" -n \
        -o "Email:         " -v "email" -n \
        -o "Teléfono:      " -v "telefono" -n \
        -o "Departamento:  " -v "departamento" -n \
        "$XML"
    echo
    echo "Historial:"
    xmlstarlet sel -t -m "/datos/personas/persona[@id='${ARGS[id]}']/historial/evento" \
        -o "  - " -v "@tipo" \
        -o " (" -v "@fecha" -o ")" \
        -o "  " -v "@motivo" -n \
        "$XML"
}

cmd_persona_crear() {
    parse_args "$@"
    need nombre; need apellidos; need email
    local email="${ARGS[email]}"
    echo "$email" | grep -qE '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' \
        || die "Email inválido: $email"
    [ -z "$(xmlstarlet sel -t -v "/datos/personas/persona[email='$email']/@id" "$XML")" ] \
        || die "Ya existe una persona con email $email"

    local id; id=$(next_id "/datos/personas/persona" "p")
    local tel="${ARGS[telefono]:-}"
    local dep="${ARGS[departamento]:-}"

    local block
    block="    <persona id=\"$id\" estado=\"activo\">
      <nombre>$(xml_escape "${ARGS[nombre]}")</nombre>
      <apellidos>$(xml_escape "${ARGS[apellidos]}")</apellidos>
      <email>$(xml_escape "$email")</email>"
    [ -n "$tel" ] && block="$block
      <telefono>$(xml_escape "$tel")</telefono>"
    [ -n "$dep" ] && block="$block
      <departamento>$(xml_escape "$dep")</departamento>"
    block="$block
      <historial>
        <evento tipo=\"creacion\" fecha=\"$(hoy)\"/>
      </historial>
    </persona>"

    with_backup insert_before '^  </personas>' "$block"
    ok "Persona creada: $id — ${ARGS[nombre]} ${ARGS[apellidos]}"
}

cmd_persona_editar() {
    parse_args "$@"
    need id
    existe_persona "${ARGS[id]}" || die "No existe la persona ${ARGS[id]}"
    local id="${ARGS[id]}" cambios=()
    local args=()

    for campo in nombre apellidos email telefono departamento; do
        if [ -n "${ARGS[$campo]:-}" ]; then
            [ "$campo" = "email" ] && {
                echo "${ARGS[email]}" | grep -qE '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' \
                    || die "Email inválido"
            }
            args+=(-u "/datos/personas/persona[@id='$id']/$campo" -v "$(xml_escape "${ARGS[$campo]}")")
            cambios+=("$campo")
        fi
    done

    [ ${#cambios[@]} -gt 0 ] || die "No indicaste ningún campo a modificar"
    local campos
    campos=$(IFS=, ; echo "${cambios[*]}")

    _editar() {
        xmlstarlet ed -L "${args[@]}" "$XML"
        add_evento "/datos/personas/persona[@id='$id']/historial" "actualizacion" "" "" 
    }
    with_backup _editar
    ok "Persona $id actualizada (campos: $campos)"
}

cmd_persona_baja() {
    parse_args "$@"
    need id; need motivo
    existe_persona "${ARGS[id]}" || die "No existe la persona ${ARGS[id]}"
    [ "$(estado_persona "${ARGS[id]}")" = "activo" ] || die "La persona ya está inactiva"

    local id="${ARGS[id]}" motivo="${ARGS[motivo]}"
    _baja() {
        # 1. Marcar persona inactiva + evento
        xmlstarlet ed -L \
            -u "/datos/personas/persona[@id='$id']/@estado" -v "inactivo" "$XML"
        add_evento "/datos/personas/persona[@id='$id']/historial" "baja" "$motivo"

        # 2. Procesar participaciones activas
        local pa_ids
        pa_ids=$(xmlstarlet sel -t -v "/datos/participaciones/participacion[@personaId='$id' and @estado='activo']/@id" "$XML")

        for pa_id in $pa_ids; do
            local yid
            yid=$(xmlstarlet sel -t -v "/datos/participaciones/participacion[@id='$pa_id']/@proyectoId" "$XML")
            xmlstarlet ed -L \
                -u "/datos/participaciones/participacion[@id='$pa_id']/@estado" -v "historico" "$XML"

            local est tit
            est=$(estado_proyecto "$yid")
            tit=$(xmlstarlet sel -t -v "/datos/proyectos/proyecto[@id='$yid']/@titularId" "$XML")

            case "$est" in
                activo|pendiente_reasignacion)
                    if [ "$tit" = "$id" ]; then
                        local restantes
                        restantes=$(xmlstarlet sel -t -v "count(/datos/participaciones/participacion[@proyectoId='$yid' and @estado='activo'])" "$XML")
                        if [ "$restantes" -eq 0 ]; then
                            xmlstarlet ed -L \
                                -u "/datos/proyectos/proyecto[@id='$yid']/@estado" -v "cancelado" \
                                -u "/datos/proyectos/proyecto[@id='$yid']/ultimaActualizacion" -v "$(hoy)" "$XML"
                            add_evento "/datos/proyectos/proyecto[@id='$yid']/historial" "cancelacion" "Baja del único participante ($id)"
                        else
                            xmlstarlet ed -L \
                                -u "/datos/proyectos/proyecto[@id='$yid']/@estado" -v "pendiente_reasignacion" \
                                -u "/datos/proyectos/proyecto[@id='$yid']/ultimaActualizacion" -v "$(hoy)" "$XML"
                            add_evento "/datos/proyectos/proyecto[@id='$yid']/historial" "pendiente_reasignacion" "Baja de $id"
                        fi
                    else
                        xmlstarlet ed -L \
                            -u "/datos/proyectos/proyecto[@id='$yid']/ultimaActualizacion" -v "$(hoy)" "$XML"
                        add_evento "/datos/proyectos/proyecto[@id='$yid']/historial" "salida" "Baja de $id"
                    fi
                    ;;
            esac
        done
    }
    with_backup _baja
    ok "Persona $id dada de baja."
}

cmd_persona_reactivar() {
    parse_args "$@"
    need id
    existe_persona "${ARGS[id]}" || die "No existe la persona ${ARGS[id]}"
    [ "$(estado_persona "${ARGS[id]}")" = "inactivo" ] || die "La persona ya está activa"
    local id="${ARGS[id]}"
    _reactivar() {
        xmlstarlet ed -L -u "/datos/personas/persona[@id='$id']/@estado" -v "activo" "$XML"
        add_evento "/datos/personas/persona[@id='$id']/historial" "reactivacion" "" ""
    }
    with_backup _reactivar
    ok "Persona $id reactivada."
}

# ============================================================
# PROYECTOS
# ============================================================
cmd_proyecto_listar() {
    printf "%-5s  %-30s  %-8s  %-22s  %-12s  %-12s\n" "ID" "NOMBRE" "TITULAR" "ESTADO" "INICIO" "FIN"
    printf "%-5s  %-30s  %-8s  %-22s  %-12s  %-12s\n" "-----" "------------------------------" "--------" "----------------------" "------------" "------------"
    xmlstarlet sel -t -m "/datos/proyectos/proyecto" \
        -v "@id" -o "|" -v "nombre" -o "|" -v "@titularId" -o "|" -v "@estado" -o "|" \
        -v "fechaInicio" -o "|" -v "fechaFin" -n "$XML" \
      | while IFS='|' read -r id nom tit est ini fin; do
            printf "%-5s  %-30s  %-8s  %-22s  %-12s  %-12s\n" "$id" "$nom" "$tit" "$est" "$ini" "${fin:-—}"
        done
}

cmd_proyecto_ver() {
    parse_args "$@"
    need id
    existe_proyecto "${ARGS[id]}" || die "No existe el proyecto ${ARGS[id]}"
    xmlstarlet sel -t -m "/datos/proyectos/proyecto[@id='${ARGS[id]}']" \
        -o "ID:           " -v "@id" -n \
        -o "Estado:       " -v "@estado" -n \
        -o "Titular:      " -v "@titularId" -n \
        -o "Nombre:       " -v "nombre" -n \
        -o "Descripción:  " -v "descripcion" -n \
        -o "Inicio:       " -v "fechaInicio" -n \
        -o "Fin:          " -v "fechaFin" -n \
        -o "Actualizado:  " -v "ultimaActualizacion" -n \
        -o "Presupuesto:  " -v "presupuesto/@moneda" -o " " -v "presupuesto" -n \
        "$XML"
    echo
    echo "Equipo:"
    xmlstarlet sel -t -m "/datos/participaciones/participacion[@proyectoId='${ARGS[id]}']" \
        -o "  - " -v "@personaId" -o "  rol=" -v "@rol" -o "  estado=" -v "@estado" -n "$XML"
    echo
    echo "Historial:"
    xmlstarlet sel -t -m "/datos/proyectos/proyecto[@id='${ARGS[id]}']/historial/evento" \
        -o "  - " -v "@tipo" -o " (" -v "@fecha" -o ")  " -v "@motivo" -n "$XML"
}

cmd_proyecto_crear() {
    parse_args "$@"
    need nombre; need descripcion; need titular
    existe_persona "${ARGS[titular]}" || die "No existe la persona ${ARGS[titular]}"
    [ "$(estado_persona "${ARGS[titular]}")" = "activo" ] || die "La persona titular debe estar activa"

    local id; id=$(next_id "/datos/proyectos/proyecto" "pr")
    local pa_id; pa_id=$(next_id "/datos/participaciones/participacion" "pa")
    local ini="${ARGS[inicio]:-$(hoy)}"
    local fin="${ARGS[fin]:-}"
    local monto="${ARGS[monto]:-}"
    local mon="${ARGS[moneda]:-USD}"

    local block
    block="    <proyecto id=\"$id\" titularId=\"${ARGS[titular]}\" estado=\"activo\">
      <nombre>$(xml_escape "${ARGS[nombre]}")</nombre>
      <descripcion>$(xml_escape "${ARGS[descripcion]}")</descripcion>
      <fechaInicio>$ini</fechaInicio>"
    [ -n "$fin" ] && block="$block
      <fechaFin>$fin</fechaFin>"
    block="$block
      <ultimaActualizacion>$(hoy)</ultimaActualizacion>"
    [ -n "$monto" ] && block="$block
      <presupuesto moneda=\"$mon\">$monto</presupuesto>"
    block="$block
      <historial>
        <evento tipo=\"creacion\" fecha=\"$(hoy)\"/>
      </historial>
    </proyecto>"

    _crear() {
        insert_before '^  </proyectos>' "$block"
        local pa_block="    <participacion id=\"$pa_id\" personaId=\"${ARGS[titular]}\" proyectoId=\"$id\" rol=\"director\" estado=\"activo\"/>"
        insert_before '^  </participaciones>' "$pa_block"
    }
    with_backup _crear
    ok "Proyecto $id creado con titular ${ARGS[titular]} (participación $pa_id)"
}

cmd_proyecto_editar() {
    parse_args "$@"
    need id
    existe_proyecto "${ARGS[id]}" || die "No existe el proyecto ${ARGS[id]}"
    local est; est=$(estado_proyecto "${ARGS[id]}")
    [ "$est" = "activo" ] || [ "$est" = "pendiente_reasignacion" ] || die "El proyecto está $est y no admite edición"

    local id="${ARGS[id]}" args=() cambios=()
    for c in nombre descripcion; do
        [ -n "${ARGS[$c]:-}" ] && { args+=(-u "/datos/proyectos/proyecto[@id='$id']/$c" -v "$(xml_escape "${ARGS[$c]}")"); cambios+=("$c"); }
    done
    for c in inicio fin; do
        [ -n "${ARGS[$c]:-}" ] && { args+=(-u "/datos/proyectos/proyecto[@id='$id']/fecha${c^}" -v "${ARGS[$c]}"); cambios+=("fecha${c^}"); }
    done
    if [ -n "${ARGS[monto]:-}" ]; then
        args+=(-u "/datos/proyectos/proyecto[@id='$id']/presupuesto" -v "${ARGS[monto]}")
        cambios+=("presupuesto")
    fi
    if [ -n "${ARGS[moneda]:-}" ]; then
        args+=(-u "/datos/proyectos/proyecto[@id='$id']/presupuesto/@moneda" -v "${ARGS[moneda]}")
    fi

    [ ${#cambios[@]} -gt 0 ] || die "No indicaste campos a modificar"
    local campos; campos=$(IFS=, ; echo "${cambios[*]}")

    _editar() {
        xmlstarlet ed -L "${args[@]}" \
            -u "/datos/proyectos/proyecto[@id='$id']/ultimaActualizacion" -v "$(hoy)" "$XML"
        add_evento "/datos/proyectos/proyecto[@id='$id']/historial" "actualizacion" "" ""
    }
    with_backup _editar
    ok "Proyecto $id actualizado: $campos"
}

cmd_proyecto_reasignar() {
    parse_args "$@"
    need id; need nuevo
    existe_proyecto "${ARGS[id]}" || die "No existe el proyecto ${ARGS[id]}"
    existe_persona  "${ARGS[nuevo]}" || die "No existe la persona ${ARGS[nuevo]}"
    [ "$(estado_persona "${ARGS[nuevo]}")" = "activo" ] || die "El nuevo titular debe estar activo"
    local est; est=$(estado_proyecto "${ARGS[id]}")
    [ "$est" = "activo" ] || [ "$est" = "pendiente_reasignacion" ] || die "El proyecto está $est"

    local id="${ARGS[id]}" nuevo="${ARGS[nuevo]}"
    local viejo; viejo=$(xmlstarlet sel -t -v "/datos/proyectos/proyecto[@id='$id']/@titularId" "$XML")

    [ "$viejo" = "$nuevo" ] && die "La persona $nuevo ya es la titular del proyecto $id"

    _reasignar() {
        # 1. Titular viejo pasa a miembro (si sigue activo)
        xmlstarlet ed -L \
            -u "/datos/participaciones/participacion[@proyectoId='$id' and @personaId='$viejo' and @rol='director']/@rol" -v "miembro" "$XML"
        # 2. Nuevo titular: si ya participa, cambia rol a director
        local ya_participa
        ya_participa=$(xmlstarlet sel -t -v "count(/datos/participaciones/participacion[@proyectoId='$id' and @personaId='$nuevo'])" "$XML")
        if [ "$ya_participa" -gt 0 ]; then
            xmlstarlet ed -L \
                -u "/datos/participaciones/participacion[@proyectoId='$id' and @personaId='$nuevo']/@rol" -v "director" \
                -u "/datos/participaciones/participacion[@proyectoId='$id' and @personaId='$nuevo']/@estado" -v "activo" "$XML"
        else
            local pa_id; pa_id=$(next_id "/datos/participaciones/participacion" "pa")
            local pa_block="    <participacion id=\"$pa_id\" personaId=\"$nuevo\" proyectoId=\"$id\" rol=\"director\" estado=\"activo\"/>"
            insert_before '^  </participaciones>' "$pa_block"
        fi
        # 3. Actualizar proyecto
        xmlstarlet ed -L \
            -u "/datos/proyectos/proyecto[@id='$id']/@titularId" -v "$nuevo" \
            -u "/datos/proyectos/proyecto[@id='$id']/@estado"    -v "activo" \
            -u "/datos/proyectos/proyecto[@id='$id']/ultimaActualizacion" -v "$(hoy)" "$XML"
        add_evento "/datos/proyectos/proyecto[@id='$id']/historial" "reasignacion" "Titular $viejo → $nuevo"
    }
    with_backup _reasignar
    ok "Titular reasignado: $id → $nuevo"
}

cmd_proyecto_cerrar() {
    parse_args "$@"
    need id; need motivo
    existe_proyecto "${ARGS[id]}" || die "No existe el proyecto ${ARGS[id]}"
    local est; est=$(estado_proyecto "${ARGS[id]}")
    [ "$est" = "activo" ] || [ "$est" = "pendiente_reasignacion" ] || die "El proyecto ya está $est"

    local id="${ARGS[id]}" motivo="${ARGS[motivo]}"
    _cerrar() {
        local fin=""
        fin=$(xmlstarlet sel -t -v "/datos/proyectos/proyecto[@id='$id']/fechaFin" "$XML")
        if [ -z "$fin" ]; then
            xmlstarlet ed -L -s "/datos/proyectos/proyecto[@id='$id']" -t elem -n fechaFin -v "$(hoy)" "$XML"
        fi
        xmlstarlet ed -L \
            -u "/datos/proyectos/proyecto[@id='$id']/@estado" -v "cerrado" \
            -u "/datos/proyectos/proyecto[@id='$id']/ultimaActualizacion" -v "$(hoy)" "$XML"
        add_evento "/datos/proyectos/proyecto[@id='$id']/historial" "cierre" "$motivo"
    }
    with_backup _cerrar
    ok "Proyecto $id cerrado."
}

cmd_proyecto_cancelar() {
    parse_args "$@"
    need id; need motivo
    existe_proyecto "${ARGS[id]}" || die "No existe el proyecto ${ARGS[id]}"
    local id="${ARGS[id]}" motivo="${ARGS[motivo]}"
    _cancelar() {
        xmlstarlet ed -L \
            -u "/datos/proyectos/proyecto[@id='$id']/@estado" -v "cancelado" \
            -u "/datos/proyectos/proyecto[@id='$id']/ultimaActualizacion" -v "$(hoy)" "$XML"
        add_evento "/datos/proyectos/proyecto[@id='$id']/historial" "cancelacion" "$motivo"
    }
    with_backup _cancelar
    ok "Proyecto $id cancelado."
}

# ============================================================
# PARTICIPACIONES
# ============================================================
cmd_participacion_agregar() {
    parse_args "$@"
    need persona; need proyecto
    local per="${ARGS[persona]}" proy="${ARGS[proyecto]}" rol="${ARGS[rol]:-miembro}"
    existe_persona "$per"  || die "No existe persona $per"
    existe_proyecto "$proy" || die "No existe proyecto $proy"
    [ "$(estado_persona "$per")" = "activo" ] || die "La persona debe estar activa"
    local est; est=$(estado_proyecto "$proy")
    [ "$est" = "activo" ] || [ "$est" = "pendiente_reasignacion" ] || die "El proyecto está $est"
    [ "$rol" = "miembro" ] || [ "$rol" = "observador" ] || die "Rol debe ser 'miembro' u 'observador'"

    local exists
    exists=$(xmlstarlet sel -t -v "count(/datos/participaciones/participacion[@personaId='$per' and @proyectoId='$proy' and @estado='activo'])" "$XML")
    [ "$exists" -eq 0 ] || die "La persona ya participa activamente en este proyecto"

    local pa_id; pa_id=$(next_id "/datos/participaciones/participacion" "pa")
    local block="    <participacion id=\"$pa_id\" personaId=\"$per\" proyectoId=\"$proy\" rol=\"$rol\" estado=\"activo\"/>"

    _agregar() {
        insert_before '^  </participaciones>' "$block"
        xmlstarlet ed -L -u "/datos/proyectos/proyecto[@id='$proy']/ultimaActualizacion" -v "$(hoy)" "$XML"
        add_evento "/datos/proyectos/proyecto[@id='$proy']/historial" "actualizacion" "Alta de $per como $rol"
    }
    with_backup _agregar
    ok "Participación creada: $pa_id ($per en $proy como $rol)"
}

cmd_participacion_rol() {
    parse_args "$@"
    need id; need rol
    [ "${ARGS[rol]}" = "miembro" ] || [ "${ARGS[rol]}" = "observador" ] \
        || die "Rol debe ser 'miembro' u 'observador'"
    local pa_id="${ARGS[id]}" rol="${ARGS[rol]}"
    local cnt; cnt=$(xmlstarlet sel -t -v "count(/datos/participaciones/participacion[@id='$pa_id'])" "$XML")
    [ "$cnt" -gt 0 ] || die "No existe la participación $pa_id"
    local rol_actual; rol_actual=$(xmlstarlet sel -t -v "/datos/participaciones/participacion[@id='$pa_id']/@rol" "$XML")
    [ "$rol_actual" != "director" ] || die "No se puede cambiar el rol del director; usa proyecto-reasignar"

    local proy; proy=$(xmlstarlet sel -t -v "/datos/participaciones/participacion[@id='$pa_id']/@proyectoId" "$XML")
    local per; per=$(xmlstarlet sel -t -v "/datos/participaciones/participacion[@id='$pa_id']/@personaId" "$XML")

    _cambiar() {
        xmlstarlet ed -L -u "/datos/participaciones/participacion[@id='$pa_id']/@rol" -v "$rol" "$XML"
        add_evento "/datos/proyectos/proyecto[@id='$proy']/historial" "actualizacion" "$per: $rol_actual → $rol"
    }
    with_backup _cambiar
    ok "Rol de $pa_id cambiado a $rol"
}

cmd_participacion_salir() {
    parse_args "$@"
    need id
    local pa_id="${ARGS[id]}"
    local cnt; cnt=$(xmlstarlet sel -t -v "count(/datos/participaciones/participacion[@id='$pa_id'])" "$XML")
    [ "$cnt" -gt 0 ] || die "No existe la participación $pa_id"
    local estado; estado=$(xmlstarlet sel -t -v "/datos/participaciones/participacion[@id='$pa_id']/@estado" "$XML")
    [ "$estado" = "activo" ] || die "La participación ya es histórica"
    local rol; rol=$(xmlstarlet sel -t -v "/datos/participaciones/participacion[@id='$pa_id']/@rol" "$XML")
    [ "$rol" != "director" ] || die "No se puede sacar al director; usa proyecto-reasignar"

    local proy; proy=$(xmlstarlet sel -t -v "/datos/participaciones/participacion[@id='$pa_id']/@proyectoId" "$XML")
    local per; per=$(xmlstarlet sel -t -v "/datos/participaciones/participacion[@id='$pa_id']/@personaId" "$XML")
    local motivo="${ARGS[motivo]:-Salida de $per}"

    _salir() {
        xmlstarlet ed -L -u "/datos/participaciones/participacion[@id='$pa_id']/@estado" -v "historico" "$XML"
        xmlstarlet ed -L -u "/datos/proyectos/proyecto[@id='$proy']/ultimaActualizacion" -v "$(hoy)" "$XML"
        add_evento "/datos/proyectos/proyecto[@id='$proy']/historial" "salida" "$motivo"
    }
    with_backup _salir
    ok "Participación $pa_id finalizada."
}

# ============================================================
# DISPATCHER
# ============================================================
case "$CMD" in
    ayuda|-h|--help|help) cmd_ayuda ;;
    validar)              cmd_validar ;;

    persona-listar)       cmd_persona_listar "$@" ;;
    persona-ver)          cmd_persona_ver "$@" ;;
    persona-crear)        cmd_persona_crear "$@" ;;
    persona-editar)       cmd_persona_editar "$@" ;;
    persona-baja)         cmd_persona_baja "$@" ;;
    persona-reactivar)    cmd_persona_reactivar "$@" ;;

    proyecto-listar)      cmd_proyecto_listar "$@" ;;
    proyecto-ver)         cmd_proyecto_ver "$@" ;;
    proyecto-crear)       cmd_proyecto_crear "$@" ;;
    proyecto-editar)      cmd_proyecto_editar "$@" ;;
    proyecto-reasignar)   cmd_proyecto_reasignar "$@" ;;
    proyecto-cerrar)      cmd_proyecto_cerrar "$@" ;;
    proyecto-cancelar)    cmd_proyecto_cancelar "$@" ;;

    participacion-agregar) cmd_participacion_agregar "$@" ;;
    participacion-rol)     cmd_participacion_rol "$@" ;;
    participacion-salir)   cmd_participacion_salir "$@" ;;

    *) rojo "Comando desconocido: $CMD"; echo; cmd_ayuda; exit 1 ;;
esac