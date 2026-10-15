<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <xsl:output method="html" encoding="UTF-8" indent="yes"/>

    <!-- Relacionar identificadores con personas -->
    <xsl:key name="personaPorId"
             match="persona"
             use="@id"/>

    <!-- Relacionar participaciones con proyectos -->
    <xsl:key name="participacionesPorProyecto"
             match="participacion"
             use="@proyectoId"/>

    <xsl:template match="/datos">
        <html lang="es">
        <head>
            <meta charset="UTF-8"/>
            <meta name="viewport"
                  content="width=device-width, initial-scale=1.0"/>

            <title>Gestión de personas y proyectos</title>

            <style>
                * {
                    box-sizing: border-box;
                }

                body {
                    margin: 0;
                    padding: 30px;
                    font-family: Arial, sans-serif;
                    background: #f3f6fb;
                    color: #263247;
                }

                header {
                    background: #172b4d;
                    color: white;
                    padding: 28px;
                    border-radius: 12px;
                    margin-bottom: 25px;
                }

                header h1 {
                    margin: 0 0 8px;
                }

                header p {
                    margin: 0;
                    color: #d5dfef;
                }

                .resumen {
                    display: grid;
                    grid-template-columns:
                        repeat(auto-fit, minmax(180px, 1fr));
                    gap: 16px;
                    margin-bottom: 30px;
                }

                .tarjeta {
                    background: white;
                    padding: 22px;
                    border-radius: 10px;
                    border: 1px solid #e1e7f0;
                }

                .tarjeta h3 {
                    margin: 0 0 12px;
                    font-size: 14px;
                    color: #63718a;
                }

                .numero {
                    font-size: 30px;
                    font-weight: bold;
                    color: #2457a7;
                }

                section {
                    background: white;
                    padding: 24px;
                    border-radius: 12px;
                    margin-bottom: 28px;
                    overflow-x: auto;
                }

                h2 {
                    margin-top: 0;
                    color: #172b4d;
                }

                table {
                    width: 100%;
                    border-collapse: collapse;
                    min-width: 650px;
                }

                th, td {
                    text-align: left;
                    padding: 13px;
                    border-bottom: 1px solid #e8edf4;
                    vertical-align: top;
                }

                th {
                    background: #f5f7fb;
                    color: #52627b;
                    font-size: 13px;
                }

                td {
                    font-size: 14px;
                }

                .estado {
                    display: inline-block;
                    padding: 5px 9px;
                    border-radius: 20px;
                    font-size: 12px;
                    font-weight: bold;
                }

                .activo {
                    color: #187347;
                    background: #dff6e9;
                }

                .inactivo,
                .cancelado {
                    color: #a12e35;
                    background: #fde5e6;
                }

                .cerrado,
                .historico {
                    color: #52627b;
                    background: #e9edf3;
                }

                .pendiente_reasignacion {
                    color: #8b5a00;
                    background: #fff0cc;
                }

                .director {
                    color: #254fa1;
                    font-weight: bold;
                }

                .descripcion {
                    min-width: 220px;
                    max-width: 350px;
                }

                footer {
                    text-align: center;
                    color: #718096;
                    padding: 12px;
                    font-size: 13px;
                }

                @media (max-width: 600px) {
                    body {
                        padding: 12px;
                    }

                    header, section {
                        padding: 18px;
                    }
                }
            </style>
        </head>

        <body>
            <header>
                <h1>Panel de gestión</h1>
                <p>Directorio de personas, proyectos y participaciones</p>
            </header>

            <!-- RESUMEN -->
            <div class="resumen">
                <div class="tarjeta">
                    <h3>Total de personas</h3>
                    <div class="numero">
                        <xsl:value-of select="count(personas/persona)"/>
                    </div>
                </div>

                <div class="tarjeta">
                    <h3>Personas activas</h3>
                    <div class="numero">
                        <xsl:value-of
                            select="count(personas/persona[@estado='activo'])"/>
                    </div>
                </div>

                <div class="tarjeta">
                    <h3>Total de proyectos</h3>
                    <div class="numero">
                        <xsl:value-of select="count(proyectos/proyecto)"/>
                    </div>
                </div>

                <div class="tarjeta">
                    <h3>Proyectos activos</h3>
                    <div class="numero">
                        <xsl:value-of
                            select="count(proyectos/proyecto[@estado='activo'])"/>
                    </div>
                </div>

                <div class="tarjeta">
                    <h3>Pendientes de reasignación</h3>
                    <div class="numero">
                        <xsl:value-of
                            select="count(proyectos/proyecto[@estado='pendiente_reasignacion'])"/>
                    </div>
                </div>
            </div>

            <!-- PERSONAS -->
            <section>
                <h2>Directorio de personas</h2>

                <table>
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Nombre completo</th>
                            <th>Correo electrónico</th>
                            <th>Teléfono</th>
                            <th>Departamento</th>
                            <th>Estado</th>
                        </tr>
                    </thead>

                    <tbody>
                        <xsl:for-each select="personas/persona">
                            <tr>
                                <td><xsl:value-of select="@id"/></td>

                                <td>
                                    <xsl:value-of select="nombre"/>
                                    <xsl:text> </xsl:text>
                                    <xsl:value-of select="apellidos"/>
                                </td>

                                <td><xsl:value-of select="email"/></td>
                                <td><xsl:value-of select="telefono"/></td>
                                <td><xsl:value-of select="departamento"/></td>

                                <td>
                                    <span>
                                        <xsl:attribute name="class">
                                            <xsl:text>estado </xsl:text>
                                            <xsl:value-of select="@estado"/>
                                        </xsl:attribute>

                                        <xsl:value-of select="@estado"/>
                                    </span>
                                </td>
                            </tr>
                        </xsl:for-each>
                    </tbody>
                </table>
            </section>

            <!-- PROYECTOS -->
            <section>
                <h2>Catálogo de proyectos</h2>

                <table>
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Proyecto</th>
                            <th>Titular</th>
                            <th>Estado</th>
                            <th>Inicio</th>
                            <th>Fin</th>
                            <th>Última actualización</th>
                            <th>Presupuesto</th>
                        </tr>
                    </thead>

                    <tbody>
                        <xsl:for-each select="proyectos/proyecto">
                            <tr>
                                <td><xsl:value-of select="@id"/></td>
                                <td>
                                    <strong>
                                        <xsl:value-of select="nombre"/>
                                    </strong>
                                    <br/>
                                    <span class="descripcion">
                                        <xsl:value-of select="descripcion"/>
                                    </span>
                                </td>

                                <td>
                                    <xsl:variable name="titular"
                                                  select="@titularId"/>

                                    <xsl:value-of
                                        select="key('personaPorId', $titular)/nombre"/>
                                    <xsl:text> </xsl:text>
                                    <xsl:value-of
                                        select="key('personaPorId', $titular)/apellidos"/>
                                </td>

                                <td>
                                    <span>
                                        <xsl:attribute name="class">
                                            <xsl:text>estado </xsl:text>
                                            <xsl:value-of select="@estado"/>
                                        </xsl:attribute>

                                        <xsl:value-of select="@estado"/>
                                    </span>
                                </td>

                                <td><xsl:value-of select="fechaInicio"/></td>

                                <td>
                                    <xsl:choose>
                                        <xsl:when test="fechaFin">
                                            <xsl:value-of select="fechaFin"/>
                                        </xsl:when>
                                        <xsl:otherwise>No definida</xsl:otherwise>
                                    </xsl:choose>
                                </td>

                                <td>
                                    <xsl:value-of select="ultimaActualizacion"/>
                                </td>

                                <td>
                                    <xsl:choose>
                                        <xsl:when test="presupuesto">
                                            <xsl:value-of
                                                select="presupuesto/@moneda"/>
                                            <xsl:text> </xsl:text>
                                            <xsl:value-of select="presupuesto"/>
                                        </xsl:when>
                                        <xsl:otherwise>No definido</xsl:otherwise>
                                    </xsl:choose>
                                </td>
                            </tr>
                        </xsl:for-each>
                    </tbody>
                </table>
            </section>

            <!-- PARTICIPACIONES -->
            <section>
                <h2>Participaciones por proyecto</h2>

                <table>
                    <thead>
                        <tr>
                            <th>Proyecto</th>
                            <th>Persona</th>
                            <th>Rol</th>
                            <th>Estado de participación</th>
                        </tr>
                    </thead>

                    <tbody>
                        <xsl:for-each select="participaciones/participacion">
                            <tr>
                                <td>
                                    <xsl:value-of
                                        select="key('proyectoPorId', @proyectoId)/nombre"/>
                                    <xsl:if test="not(key('proyectoPorId', @proyectoId))">
                                        <xsl:value-of select="@proyectoId"/>
                                    </xsl:if>
                                </td>

                                <td>
                                    <xsl:variable name="persona"
                                                  select="@personaId"/>

                                    <xsl:value-of
                                        select="key('personaPorId', $persona)/nombre"/>
                                    <xsl:text> </xsl:text>
                                    <xsl:value-of
                                        select="key('personaPorId', $persona)/apellidos"/>
                                </td>

                                <td>
                                    <xsl:choose>
                                        <xsl:when test="@rol='director'">
                                            <span class="director">Director</span>
                                        </xsl:when>
                                        <xsl:when test="@rol='miembro'">
                                            Miembro
                                        </xsl:when>
                                        <xsl:otherwise>Observador</xsl:otherwise>
                                    </xsl:choose>
                                </td>

                                <td>
                                    <span>
                                        <xsl:attribute name="class">
                                            <xsl:text>estado </xsl:text>
                                            <xsl:value-of select="@estado"/>
                                        </xsl:attribute>

                                        <xsl:value-of select="@estado"/>
                                    </span>
                                </td>
                            </tr>
                        </xsl:for-each>
                    </tbody>
                </table>
            </section>

            <footer>
                Sistema de gestión de personas y proyectos
            </footer>
        </body>
        </html>
    </xsl:template>

    <!-- Índice para localizar el nombre del proyecto -->
    <xsl:key name="proyectoPorId"
             match="proyecto"
             use="@id"/>

</xsl:stylesheet>