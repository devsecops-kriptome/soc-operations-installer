# SOC Operations Installer

Distribución pública cifrada para Wazuh 4.14.7/4.14.8, AIO o distribuido con un único Dashboard.
No se publica código privado, TAR sin cifrar, configuraciones reales, respaldos ni identidades age.
La identidad original se obtiene solo en el gestor autorizado: `SOC Operations Installer Descifrado`.

## Versión vigente

- Instalador: `0.1.188`; API, API externa, worker y agente: `0.1.131`.
- Plugin: `socOperations@0.1.111`, compilado para cada plataforma exacta.
- Esquema: `c8d3e902f751`, sin nuevas migraciones desde `0.1.181`.
- Wazuh `4.14.7-1` / OSD `2.19.5`, o Wazuh `4.14.8-1` / OSD `2.19.6`.

0.1.188 corrige las exclusiones `campo != valor`: los campos ausentes/nulos no
bloquean por esa exclusión, manteniendo el resto de requisitos AND, tenant y deduplicación.
Verifica estrictamente cadena, propósito, IP y DNS de certificados con `openssl verify`.
Incluye los correctivos locales de bloqueos/permisos y renovación mTLS coordinada local:
cada seis horas, anticipación siete días, vigencia 30 días. La coordinación automática
requiere Manager/agente y runtime en el mismo host; no distribuye credenciales entre hosts.
Imagen, wheel y ambos plugins se recompilan. No cambian alcances API/RBAC ni el esquema.
No hay replay de alertas históricas. Ver [notas](docs/release-0.1.188.md) y
[actualización](docs/upgrade-0.1.188.md). No es necesario instalar los candidatos locales
0.1.186/0.1.187. Publicar no despliega ni elimina versiones o respaldos anteriores.

0.1.185 corrige la contaminación de la configuración temporal del agente por un mensaje
de diagnóstico durante la transición de Compose. El mensaje va a stderr: no se modifica
agent.env a mano ni se relajan validaciones. Aplica a las transiciones aprobadas, tanto
actualizaciones normales como recuperación revisada de un intento interrumpido. No es
una excepción para un host ni una autorización de todas las versiones antiguas. Imagen,
wheel, plugins y Compose permanecen idénticos a 0.1.184. Ver
[notas 0.1.185](docs/release-0.1.185.md) y [actualización](docs/upgrade-0.1.185.md).

0.1.184 permite la transición controlada desde el Compose histórico verificado utilizado
por instalaciones como 0.1.166. No es un paquete específico para un host: reconoce una huella
exacta únicamente durante el upgrade, con estado y permisos protegidos. Los archivos
alterados o desconocidos siguen rechazados. Conserva byte a byte runtime, wheel, plugins
y Compose de 0.1.183; no cambia IP, hostname ni credenciales del destino. Ver
[notas 0.1.184](docs/release-0.1.184.md) y [actualización](docs/upgrade-0.1.184.md).

0.1.183 añade menús de acciones en Credenciales de API y Playbooks, bloqueo de solicitudes
duplicadas de revocación/eliminación y exportación de playbooks según rol y tenant.
Incluye el correctivo de salida de la API externa por frontend, confianza acotada a gateways
del host y aceptación desde su propio contenedor. No amplía alcances ni modifica UFW/TLS/mTLS.
API/worker/agente conservan la imagen 0.1.130 verificada; ambos plugins se recompilan como
0.1.110. Ver [notas 0.1.183](docs/release-0.1.183.md) y
[actualización desde 0.1.181](docs/upgrade-0.1.183.md). El correctivo local 0.1.182 está incluido;
no es necesario instalarlo por separado. Publicar no despliega ni limpia LAUFEY.

0.1.181 añadió métricas externas de casos, eventos, SLA y analistas, estado e historial de
agentes y consulta de tecnologías con `technologies:read`. El historial de conectividad
comienza después del upgrade: cada cinco minutos y retención de 30 días, configurables.
Incluye activación de tecnologías, edición autorizada de alcances, ajustes de reportes y
protección de Usuarios contra respuestas obsoletas de otro tenant. API/worker/agente usan
una misma versión y el Compose aprobado mantiene su huella. Ver
[notas 0.1.181](docs/release-0.1.181.md) y [actualización](docs/upgrade-0.1.181.md).
La publicación no despliega ni elimina paquetes o respaldos del servidor.

0.1.180 corrigió la validación cruzada del Compose del provisionador y evita marcar
`complete` antes de terminar la reconciliación posterior a la custodia. Conserva los
artefactos de API/agente/plugin y el esquema de 0.1.179. Para una actualización 0.1.179
detenida, usar el paquete 0.1.180 verificado: no cambiar al Compose antiguo ni omitir
validaciones. Ver [notas del correctivo](docs/release-0.1.180.md) y
[recuperación y actualización](docs/upgrade-0.1.180.md).

0.1.179 incorpora el [resumen externo de vulnerabilidades por grupo](docs/vulnerability-summary-api.md):
CVE únicos por CVSS, Top 10 CVE/dispositivos y cortes cada 24 horas con historial y estado de
actualización. Conserva el último corte válido ante errores; la primera recopilación completa
es obligatoria y su fecha no se presenta como fecha de escaneo de Wazuh. El listado paginado
existente sigue en directo y el alcance sigue siendo `vulnerabilities:read`.

0.1.179 incluyó Tecnologías externas inicialmente solo con JWT interno; 0.1.181 permite
consultarlas con una clave externa que tenga `technologies:read`. Se conservan el filtro de
actividad de casos, hijos agrupados y creación manual con descripción amplia/adjuntos.
Reportes Word/Excel: ALL o grupos específicos, dos agrupaciones, justificaciones opcionales,
muestras de hasta tres CVE, totales completos, CTI y tablas alineadas. Ver las
[notas funcionales](docs/release-0.1.179.md) y la [guía vigente de actualización](docs/upgrade-0.1.188.md).
Publicar no instala ni modifica producción; se necesita un respaldo nuevo antes del upgrade.

0.1.178 corrigió la API externa: permite la ruta exacta de vulnerabilidades por el gateway,
exige `metrics:read` para las estadísticas por cliente y proyecta eventos e historial de hijos
en el padre sin mover su propiedad. Corrige los contadores de SLA abiertos y conserva el
encabezado de autenticación del 401. Las rutas, claves y parámetros existentes se mantienen;
cambian los totales/páginas de familias y la presencia de estadísticas según permisos.
Consultar las [notas](docs/release-0.1.178.md) y la
[actualización desde 0.1.176 o 0.1.177](docs/upgrade-0.1.178.md).
Conserva los indicadores por analista, escalamiento y mejoras de casos de 0.1.177.
La aceptación productiva sigue pendiente; publicar no actualiza ningún servidor.

Incluye lecturas de vulnerabilidades completas mediante spool en disco para consolidado, reportes,
simulación y agrupación. No eleva las protecciones del worker ni acepta inventarios parciales.
El reporte muestra progreso de lectura/generación. Calendarios más ágiles, matriz horaria agrupada,
edición de turnos por día/programación, colores, turnos personalizados y reporte de ausencias.
SLA separa ACK y autoescalamiento (5 minutos por defecto), con canales autorizados por integración,
switches, reset y guardado por grupo/todo. Casos: análisis antes del ACK, confirmación sin texto,
acciones compactas, actualización cada 30 segundos y periodos de consulta.

0.1.172 evita retener el bloqueo global de auditoría durante consultas externas del worker,
añade la ruta exacta de continuación/liberación de inventario y el filtro de últimos 7 días.
Permite responsables múltiples, prioridad Analista → SOC Manager → Ingeniería y excluye Junior
como responsable. La programación fija antigua permite editar fechas futuras compatibles con
vista previa; las recargas no descartan borradores SLA del mismo tenant.

0.1.173 corrige el consolidado y los reportes cuando el escáner identifica el nodo con un
nombre distinto del clúster configurado. El agente entrega el hostname por el inventario mTLS;
el backend exige despliegue, agente, grupo e índice exactos. No fija nombres de servidores ni
amplía RBAC/DLS. Instalar en otro host no requiere cambiar el código. Renombrar un nodo existente
exige revisar los índices anteriores: no se autorizan automáticamente aliases históricos.

La cuenta institucional protegida, TLS, custodia OpenBao y datos se conservan.
[Cambios, huellas y límites](docs/release-0.1.176.md).
[Actualizar desde 0.1.175](docs/upgrade-0.1.176.md): respaldo NUEVO y ventana obligatorios;
no usar instalación limpia, `apply`, inicialización de OpenBao ni borrado de volúmenes.

0.1.176 incorpora Excel con hasta 10 CVE distintos recientes por host y paquete, hojas por
grupo seleccionado y eliminación autorizada de reportes anteriores. El Word conserva los
totales completos de hallazgos y avisa cuando la tabla es una muestra. Corrige la variante
de nombre de ASP.NET Core con y sin separador antes de Shared Framework sin unir versiones
ni arquitecturas distintas. Los eventos siguen perteneciendo al hijo y el padre los consulta
con procedencia; cambios del padre se propagan a los hijos con justificación y auditoría.
Las notas identifican los defectos visuales de Word aún pendientes y los límites de validación.

0.1.175 incorpora Datos extras del caso, números diarios, vistas compacta/extendida y unión manual
de casos con ACK del actor, SLA originales y cierre independiente o propagado a hijos abiertos.
Reportes de vulnerabilidades usa inventario vigente, grupos y tres agrupaciones, consolidación de
paquetes y transmisión CSV; Envío programado no solicita perfil. Incluye formularios alineados,
menús de tres puntos y playbook vertical plegado. La aceptación de reportes reales en producción
sigue pendiente; las notas detallan el alcance de las pruebas y la migración.

0.1.174 añade 7 días predeterminados en Casos e incidentes, fechas personalizadas en el
Dashboard, edición de automatizaciones mediante menú ⋮, filtros Campo/Operador/Valor y
campos adicionales de eventos. Vulnerabilidades presentes incorpora grupo, SO y nombre.
La ordenación SQLite del reporte usa un índice y su temporal se dirige al volumen de reportes,
conservando el contenedor read-only, /tmp de 64 MiB y el rechazo de reportes parciales.

Validación de 0.1.174: 792 pruebas backend/agente y 17 adicionales con PostgreSQL real desechable,
incluidas RLS; 144 pruebas frontend. Ambos plugins se recompilan para OSD 2.19.5 y 2.19.6.
Wheel e imagen verificados contra la fuente, pip check, 52 archivos de migración/configuración
y desempaque completo con hashes internos correctos. TypeScript aprobado; persisten 33
diagnósticos mypy previos, sin nuevos en el alcance comparado.
Defecto conocido pendiente: un ID de agente reutilizado puede mostrar SO/IP del reemplazo
bajo el nombre anterior dentro del mismo tenant. Revisar la identidad antes de basarse en esos metadatos.
La aceptación contra el Indexer y el navegador de producción sigue pendiente.
Revisión visual Word/PDF con el renderizador requerido y aceptación en LAUFEY PENDIENTES.
Publicar no instala en el servidor ni modifica Wazuh, HAProxy, Coraza o CSP.
La revisión local muestra mejoras de calendario; no garantiza idénticos tiempos en producción.
Los releases anteriores y sus activos se conservan inmutables.

Conserva los cambios de `0.1.159`, que corrige los helpers GeoIP del distribuidor y los Indexers: usa el builtin
`command -v` para comprobar dependencias, no el ejecutable inexistente `/usr/bin/command`.
La guía WA01 añade numeración jerárquica, avisos destacados y detención de los bloques
GeoIP si falla el preflight, conservando los enlaces a diagnósticos existentes.

Conserva la corrección de `0.1.158` de la validación de versión del agente: consulta los metadatos de la
distribución instalada (0.1.113), no el valor interno desactualizado de `__version__`.
También valida el entorno antes de reutilizar una instalación parcial. El wheel no cambia.

Conserva la corrección de `0.1.157` de la comprobación del branding para admitir Dashboard 4.14.7 y 4.14.8,
conservando las validaciones de destinos, hashes, respaldo y rollback.

Desde `0.1.156` se comprueba CPU `x86_64` y nivel `x86-64-v2` en todos los procesadores visibles durante
el preflight, antes de instalar componentes. Si faltan instrucciones, las identifica y solicita
corregir el modelo de CPU de la VM. El helper de dependencias también realiza ese control.

Conserva la imagen recuperada de MinIO incorporada en `0.1.155` dentro del TAR cifrado.
Verifica su SHA-256, la importa, comprueba identidad y plataforma y usa una etiqueta local con
las descargas deshabilitadas para MinIO. Conserva las correcciones de topología de `0.1.154`,
las dos parejas Wazuh/OSD y los mismos artefactos de API y plugin.

Si `0.1.153` quedó detenido en `dashboard-plugin`, seguir la
[recuperación de la instalación parcial](docs/wa01-produccion-distribuida-wazuh-4.14.8.md#retomar-el-fallo-de-conexión-del-release-01153).
Se debe repetir `apply` con el staging nuevo y conservar los estados de los pasos completados.

Validación de 0.1.159: 67 pruebas locales de versiones, recuperación parcial, CPU, importación, endpoints y detección de herramientas GeoIP, sintaxis Bash y comprobación de los
48 artefactos del TAR. En Docker local se probó la importación y, en un contenedor sin red,
el arranque, la creación de bucket, el versionado y la carga y lectura de un objeto S3.
La comprobación de instalación real en WA01 sigue pendiente.

## Almacenamiento S3 e imagen pendiente de evaluación

El instalador despliega MinIO como almacenamiento interno compatible con S3 para evidencias.
No requiere contratar Amazon S3. El endpoint interno es `http://minio:9000` y el bucket
configurado es `soc-operations-evidence`.

La CPU visible debe soportar `x86-64-v2`. En Proxmox, `kvm64` puede ocultar instrucciones del
host; configurar un modelo compatible como `x86-64-v2-AES` o `host`, según hardware y destinos
de migración, con apagado completo y posterior encendido de la VM. Consultar el
[procedimiento de CPU para MinIO](docs/wa01-produccion-distribuida-wazuh-4.14.8.md#cpu-de-las-máquinas-virtuales-para-minio).

La imagen original recuperada corresponde a:

```text
quay.io/minio/minio:RELEASE.2025-07-23T15-54-02Z@sha256:d249d1fb6966de4d8ad26c04754b545205ff15a62e4fd19ebd0f26fa5baacbc0
```

La descarga desde el registro falló durante `apply` en WA01 con `v0.1.154`.
`v0.1.159` contiene `soc-operations-minio-image.tar.gz`, exportado del laboratorio anterior,
con SHA-256 `2223b43be55458a29e8add829dbcd0cc0fda68872c104df6f5e475144b492598`.
Se incluye únicamente `linux/amd64`, sin volúmenes, credenciales ni evidencias.
MinIO se carga localmente y no consulta Quay. OpenBao y las demás imágenes todavía requieren
acceso a sus registros. Consultar la
[recuperación del fallo de descarga](docs/wa01-produccion-distribuida-wazuh-4.14.8.md#retomar-el-fallo-de-descarga-de-minio-del-release-01154).

**Esta imagen debe ser evaluada antes de aprobar su uso en producción.**
El [repositorio oficial de MinIO Community](https://github.com/minio/minio) está archivado y
declara que ya no se mantiene. Recuperar la imagen resuelve su disponibilidad, pero no acredita
soporte, ausencia de vulnerabilidades ni aptitud para producción.

El TAR cifrado incluye las licencias, los créditos y las fuentes upstream de las versiones
identificadas de MinIO y mc. Las dependencias transitivas no están vendorizadas.
Consultar [MINIO-NOTICE.md](docs/MINIO-NOTICE.md) para procedencia, términos y evaluación pendiente.
El instalador comprueba los IDs conocidos del índice OCI y de la configuración, según el
almacén de imágenes utilizado por Docker, sin depender de que `docker load` conserve `RepoDigests`.

SeaweedFS es una alternativa en evaluación, **todavía no integrada ni validada**. Cualquier
sustitución requiere comprobar las operaciones S3 utilizadas por SOC Operations, los permisos,
el cifrado, el versionado, el respaldo y la restauración. La imagen aprobada se fijará por versión
y digest; no se utilizará una etiqueta flotante `latest` en producción.

## Uso

1. Descargar `soc-operations-0.1.181.tar.gz.age` y `SHA256SUMS` desde Releases.
2. Recuperar la clave privada `age` desde el gestor de secretos autorizado, entrada
   `SOC Operations Installer Descifrado`. Nunca se publica en este repositorio.
3. Seguir [Instalación AIO](docs/installation.md) o
   [instalación distribuida](docs/distributed-installation.md). Ambas guías incluyen el bloqueo
   previo de actualizaciones Wazuh, límites iniciales de memoria y baseline de shards/réplicas.
   Para WA01 sobre Wazuh 4.14.8 consulte además la
   [guía distribuida de producción](docs/wa01-produccion-distribuida-wazuh-4.14.8.md).
4. Aplicar manualmente la política de red descrita en [Referencia de firewall](docs/firewall-reference.md).
5. En AIO o distribuido, configurar y probar el
   [respaldo y recuperación](docs/backup-and-restore.md).
6. Si se usa MaxMind, seguir la
   [guía completa de distribución centralizada de GeoLite2](docs/maxmind-geoip.md), incluida la
   instalación en Manager e Indexer, activación canaria, desactivación y rollback.

Los scripts en `scripts/` verifican primero SHA-256, descifran el asset y vuelven a validar el TAR
antes de extraerlo.

## Modelo de seguridad

- La cuenta inicial `soc_engineering` es institucional y protegida, no personal. Define su
  contraseña mediante un prompt oculto durante `resume`; las cuentas individuales se usan a diario.
- No se genera un correo de activación inicial.
- SMTP se configura después desde la interfaz para los usuarios posteriores.
- El instalador no abre puertos ni modifica UFW, nftables o iptables.
- La clave privada de distribución se custodia bajo `SOC Operations Installer Descifrado` en el
  gestor de secretos autorizado; su valor y los secretos del servidor permanecen fuera de GitHub.
- Wazuh 4.12 no es compatible con este paquete; consulte la
  [matriz de compatibilidad](docs/compatibility.md).

Consulte [SECURITY.md](SECURITY.md) antes de reportar una vulnerabilidad.
