# SOC Operations 0.1.173

Corrige el consolidado de vulnerabilidades por host y la agrupación del reporte cuando el
nombre de nodo de los hallazgos difiere del clúster configurado. Instalador `0.1.173`;
API, API externa, worker y agente `0.1.123`; plugin sin cambios `0.1.103`.
Esquema `c17e89ab2304`, sin migraciones nuevas desde `0.1.172`.

## Alcance de la corrección

El agente comunica el hostname del Manager por el inventario mTLS existente. El backend
mantiene el nombre configurado del clúster y admite la identidad de nodo únicamente si
coinciden despliegue, agente único, nombre, grupo principal de tenant e índice exacto del nodo.
Rechaza marcadores de tenant contradictorios, índices ajenos e identidades ambiguas.
Un fallo sigue siendo un error: no devuelve un consolidado parcial ni un reporte vacío exitoso.

No hay un hostname fijo ni un alias aprendido de los propios hallazgos. Una instalación nueva
obtiene su identidad dinámicamente. Un cambio de hostname posterior puede dejar índices con
el nombre anterior; requiere reconciliación y revisión antes de autorizar esa transición.
No se cambian RBAC, DLS, permisos del Indexer, topología, CSP, Coraza ni custodia OpenBao.
Los plugins de ambas versiones de OpenSearch Dashboards son idénticos a los de `0.1.172`.

## Validación del paquete

759 pruebas backend aprobadas: 742 de la suite general y 17 con PostgreSQL real desechable.
Las pruebas HTTP leen 7.652 hallazgos sintéticos completos, generan Top 10 por paquete y
verifican la agrupación del reporte. Rechazan tenants, agentes, despliegues e índices ajenos
sin inventario parcial; las solicitudes no autorizadas no consultan el Indexer.
Lint y tipos de los módulos corregidos sin errores.

Wheel e imagen comparados con las fuentes instaladas, pip check correcto y 52 archivos de
migración/configuración verificados. La imagen pasó una prueba positiva y negativa sin red.
Se verificaron sintaxis Bash, las huellas internas de los 48 artefactos y el desempaque real.
La aceptación funcional contra OpenSearch y el navegador de producción sigue pendiente;
estas pruebas no garantizan latencia de producción ni aprueban visualmente Word/PDF.

## Actualización segura

Actualizar backend y agente juntos; el instalador verifica la versión nueva del agente antes
de iniciar el runtime. Para Manager remoto, actualizarlo primero siguiendo su procedimiento.
[Actualizar LAUFEY desde 0.1.172](upgrade-0.1.173-laufey.md).
Preparar respaldo NUEVO en caliente y una ventana breve para reemplazar los componentes.
El respaldo local no elimina el riesgo de pérdida del servidor ni protege cambios posteriores
al punto de recuperación. No usar `apply`, reinicializar OpenBao, borrar volúmenes o restaurar
a ciegas. Publicar este paquete no actualiza producción.

## SHA 256

| Artefacto | SHA-256 |
| --- | --- |
| SHA256SUMS externo | `34d1a955067e8ceec5c233d93919977b85449d13c81c524a7d93f38feda3bf5c` |
| TAR cifrado | `ff353d167aa72ecd1b42257b742d883a11e09437ac275e7eac081ff10a7b05c9` |
| TAR descifrado | `ab48e5d70f892532980510fb3a42841d4166a545e8d22f2518a3d8b49456c6a3` |
| soc-operations-install | `c72f2347f3924cd152a06f7e21c3584ab461e5d05fce23817bfd68230e3965fd` |

Solo se publican el TAR cifrado y el manifiesto externo para el destinatario age existente.
No se publica código privado en claro, claves, archivos del servidor ni respaldos.
Las versiones anteriores y sus activos permanecen intactos.
