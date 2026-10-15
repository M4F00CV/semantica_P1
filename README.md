# Gestión de personas y proyectos

Sistema CRUD para personas, proyectos y participaciones, implementado
**100 % en bash + XML + XSLT**, sin dependencias de Python.

## Arquitectura

| Archivo | Rol |
|---|---|
| `data/proyecto.xml` | Fuente única de verdad |
| `data/proyecto.dtd` | Validación estructural |
| `data/proyecto.xsd` | Validación estricta (tipos, enums, patrones) |
| `xsl/proyecto.xsl` | Transformación XML → HTML |
| `web/proyecto.html` | SPA con CRUD y persistencia automática |
| `out/proyecto.html` | Vista generada (solo lectura) |
| `cgi-bin/save` | Endpoint CGI en bash para persistir desde la SPA |
| `scripts/cli.sh` | CLI con xmlstarlet para operar desde consola |
| `scripts/watch.sh` | Vigila el XML y regenera la vista |
| `scripts/servir.sh` | Servidor busybox httpd + CGI |
| `scripts/validar.sh` | Valida el XML contra DTD y XSD |
| `scripts/transformar.sh` | Genera la vista XSLT desde consola |

## Requisitos

- **bash**
- **xmlstarlet** (`sudo apt install xmlstarlet`)
- **libxml2-utils** (`sudo apt install libxml2-utils`)
- **xsltproc** (`sudo apt install xsltproc`)
- **busybox** (`sudo apt install busybox`)
- **inotify-tools** (`sudo apt install inotify-tools`) — opcional, para `watch.sh`

## Uso

### Servidor (SPA + CGI)

    ./scripts/servir.sh
    # → http://localhost:8000/web/proyecto.html

### Watcher (regenera la vista en cada cambio)

    ./scripts/watch.sh

### CLI

    ./scripts/cli.sh ayuda
    ./scripts/cli.sh validar
    ./scripts/cli.sh persona-listar
    ./scripts/cli.sh proyecto-listar

    ./scripts/cli.sh persona-crear \
        --nombre "Ana" --apellidos "García" \
        --email "ana@x.com" --telefono "555-1234"

    ./scripts/cli.sh proyecto-crear \
        --nombre "Web" --descripcion "Portal" \
        --titular p001 --monto 20000

    ./scripts/cli.sh participacion-agregar \
        --persona p002 --proyecto pr001 --rol miembro

    ./scripts/cli.sh proyecto-reasignar --id pr001 --nuevo p002
    ./scripts/cli.sh persona-baja --id p001 --motivo "Renuncia"

### Validación

    ./scripts/cli.sh validar
    # o directamente:
    xmllint --noout --dtdvalid data/proyecto.dtd data/proyecto.xml
    xmllint --noout --schema   data/proyecto.xsd data/proyecto.xml

## Flujo de persistencia

### SPA → XML

1. Cada cambio en la SPA se serializa con `toXML(DB)`.
2. Se envía por `POST /cgi-bin/save`.
3. El CGI valida con `xmllint` (DTD + XSD).
4. Si es válido, escribe `data/proyecto.xml` (con backup previo).
5. Se regenera `out/proyecto.html` con `xsltproc`.

### CLI → XML

1. Cada comando hace backup a `data/.backups/`.
2. Modifica el XML con `xmlstarlet`.
3. Valida el resultado.
4. Si algo falla, restaura el backup automáticamente.

### XML → SPA (polling)

1. La SPA consulta `/data/proyecto.xml` cada 3 segundos.
2. Si el contenido difiere del estado local, actualiza `DB` y re-renderiza.

## Reglas de negocio

- Al crear un proyecto se genera automáticamente la participación
  del titular como `director`.
- Al dar de baja a una persona:
  - Sus participaciones pasan a `historico`.
  - Si era titular y quedan más integrantes activos → el proyecto pasa
    a `pendiente_reasignacion`.
  - Si era titular y no quedan integrantes activos → el proyecto pasa
    a `cancelado`.
- Un proyecto cerrado o cancelado es de solo lectura.
- Reasignar titular: el director anterior pasa a `miembro`, el nuevo
  titular recibe el rol `director`.
- El director de un proyecto **no se puede quitar directamente**:
  primero se reasigna el titular.

## Estructura de estados

### Persona
- `activo` ↔ `inactivo` (baja / reactivación)

### Proyecto
- `activo` → `cerrado` (cierre normal)
- `activo` → `cancelado` (baja del único participante)
- `activo` → `pendiente_reasignacion` (baja del titular con otros activos)
- `pendiente_reasignacion` → `activo` (reasignación)

### Participación
- `activo` ↔ `historico`

## Referencias

- XML: https://www.w3.org/XML/
- XSD: https://www.w3.org/XML/Schema
- XPath: https://www.w3.org/TR/xpath/
- XSLT: https://www.w3.org/TR/xslt
