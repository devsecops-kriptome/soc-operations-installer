# SOC Operations Installer

Repositorio público de distribución del instalador SOC Operations para Wazuh 4.14.7 y 4.14.8, en
perfil AIO o distribuido con un único Dashboard.

El código fuente y el paquete sin cifrar no se publican aquí. Cada versión se distribuye como un
asset cifrado de GitHub Releases y requiere una identidad privada `age`. La identidad se recupera
únicamente desde el gestor de secretos autorizado, entrada `SOC Operations Installer Descifrado`.

## Versión vigente

- Release e instalador: `0.1.168`
- API, worker y agente: `0.1.118`
- Plugin: `socOperations@0.1.99`
- Perfiles: Wazuh `4.14.7-1` / OSD `2.19.5`, o Wazuh `4.14.8-1` / OSD `2.19.6`

Protege la cuenta inicial como **administración institucional y contingencia**, no como
cuenta personal ni identidad de ejecución de API/worker. Su UUID no puede eliminarse,
deshabilitarse ni perder Ingeniería mediante la API o mutaciones SQL normales. Las altas
nuevas requieren `--institutional-admin-account`; los upgrades conservan correo y contraseña.
No se elige otro ingeniero por antigüedad ni se reactiva automáticamente una cuenta ausente
o inactiva. Un correo personal requiere una migración de custodia separada.

El helper verifica todos los assets públicos instalados contra el ZIP, incluidos JS.gz.
El build `0.1.99-vulnerability-cursor-pagination` se muestra en cada pantalla y en About.
Un popup avisa de cambios de versión instalada y ofrece **Limpiar caché y recargar** o
**Más tarde**. Comprueba el servidor al abrir y cada 60 s con la pestaña visible, sin instalar
releases automáticamente. No recarga sin consentimiento; conserva sesión y preferencias.
Guardar los cambios pendientes antes de pulsar el botón. La primera actualización desde
0.1.96 requiere recargar para recibir el código que implementa este aviso.
Conserva los filtros opcionales y las tarjetas de contraste de 0.1.165; el operador confirmó
que los colores funcionan en WA01 después de reiniciar desde About. No se modifican CSP ni WAF.

Ingeniería global (L3) aparece en Programación de todos los tenants. SOC Manager e
ingenieros gestionan su disponibilidad compartida desde su ámbito autorizado, sin recibir
permisos sobre sus cuentas o credenciales. Los perfiles Analista, Analista Junior, SOC Manager
e Ingeniería con invitación pendiente pueden programarse; no se activa su cuenta ni se
permite login antes de aceptar. Los auditores quedan excluidos. Desactivar o bloquear una
cuenta oculta la agenda futura y conserva el historial concluido.

Vulnerability Triage consulta una sola página de 25, 50 o 100 hallazgos (50 por defecto),
con Anterior/Siguiente y el total del tenant. No descarga todo el inventario con
`all_current=true`. La selección se limita a la página visible; Actualizar vuelve a la
primera. El refresco automático no se solapa y se pausa al seleccionar o ejecutar acciones.

Validación: 562 pruebas backend aprobadas, 15 omitidas por requisitos de integración y
dos avisos de deprecación; 31 pruebas frontend aprobadas con EUI real. Ambos plugins
compilados con SDK exacto, JS/JS.gz y 48 hashes internos verificados. El chequeo global
de tipos mantiene nueve diagnósticos en código ajeno a la paginación; no es un chequeo
completamente limpio. Publicar no implica desplegar en LAUFEY.
Consultar [cambios, límites y huellas de 0.1.168](docs/release-0.1.168.md).

Conserva la corrección TLS y readiness `opensearch_query` de `0.1.164`, y las correcciones
de adopción/estado, snapshots, API externa y aprovisionamiento anteriores. No desactiva
TLS, no amplía excepciones WAF ni activa snapshots/API externa automáticamente. Los otros
43 artefactos de `0.1.167`, incluidos imagen y wheel de API/agente, se conservan byte a byte.
No reinstala ni actualiza Wazuh. El release `0.1.167` y sus activos no se reemplazan.

Para una instalación existente, seguir [upgrade a 0.1.168 en WA01](docs/upgrade-0.1.168-laufey.md),
no `apply`, inicialización de OpenBao ni borrado de volúmenes. Reservar una ventana:
Dashboard reinicia y se recrean los servicios SOC. No hay rollback global automático.
Conservar releases y respaldos anteriores. Desde 0.1.167 no añade una migración PostgreSQL:
mantiene el esquema `a2c8e4f719b6`. Exige un checkpoint NUEVO del estado 0.1.167;
el respaldo previo a esa versión no sustituye el actual. El 401 de `/api/request`
y los avisos CSP/telemetría son diagnósticos independientes, no corregidos por esta release.
No existe downgrade automático que retire la protección.

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

1. Descargar `soc-operations-0.1.168.tar.gz.age` y `SHA256SUMS` desde Releases.
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
