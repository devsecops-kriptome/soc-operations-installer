# SOC Operations Installer

Repositorio público de distribución del instalador SOC Operations para Wazuh 4.14.7 y 4.14.8, en
perfil AIO o distribuido con un único Dashboard.

El código fuente y el paquete sin cifrar no se publican aquí. Cada versión se distribuye como un
asset cifrado de GitHub Releases y requiere una identidad privada `age`. La identidad se recupera
únicamente desde el gestor de secretos autorizado, entrada `SOC Operations Installer Descifrado`.

## Versión vigente

- Release e instalador: `0.1.164`
- API, worker y agente: `0.1.115`
- Plugin: `socOperations@0.1.95`
- Perfiles: Wazuh `4.14.7-1` / OSD `2.19.5`, o Wazuh `4.14.8-1` / OSD `2.19.6`

Corrige la conexión TLS Nginx → Indexer que podía devolver 502 al consultar eventos y
vulnerabilidades cuando la URL era una IP y `proxy_ssl_name` no coincidía con el certificado.
Persiste `indexer.tls_server_name` por instalación, verifica cadena y hostname antes de cambiar
el agente y repara configuración antigua aunque el wheel ya esté instalado. Si no hay nombre
explícito, primero autentica el origen configurado (SAN de IP si la URL usa IP) y solo acepta
candidatos del certificado con cadena confiable que superan la misma
verificación de hostname usada por Nginx. No desactiva TLS ni amplía reglas WAF.

Una vez habilitado el agente, la readiness de la API prueba el gateway mTLS con el lector de OpenSearch y una búsqueda
`match_none`, tamaño cero y sin documentos. Un 502, 403, JSON inválido, timeout o shards fallidos
impide declarar disponibilidad. El instalador verifica esta ruta antes de completar el upgrade.
No cambia permisos del lector, filtros tenant ni credenciales.

El plugin elimina fondos claros fijos de las tarjetas de la Bandeja de alertas y eventos y del
resumen de casos, así como de filas seleccionadas. Usa el tema nativo de Dashboard. Renderizado
local en Edge con EUI real: contraste mínimo 11.87:1 en claro y 13.13:1 en oscuro.

Validación: 497 pruebas aprobadas, 5 omitidas por requerir PostgreSQL de integración;
prueba TLS real con SAN solo de IP y CN, rechazos explícitos, correspondencia wheel/imagen/fuentes,
migraciones sin cambios, hashes y Bash verificados. Ruff pasó en código de producción y pruebas
nuevas/modificadas; existen cinco avisos E501 previos en un test de branding ajeno a esta corrección.
Los dos plugins compilaron con sus SDK respectivos. Aceptación funcional en WA01 pendiente del upgrade.

Conserva los datos y las correcciones de adopción/estado de `0.1.163`, snapshots de `0.1.162`,
API externa de `0.1.161` y destino de aprovisionamiento de `0.1.160`. No activa snapshots o API
externa automáticamente. Los otros 39 artefactos de `0.1.163` se conservan byte a byte, incluyendo
MinIO, dependencias, branding y GeoIP `0.1.159`. No reinstala ni actualiza Wazuh.

Para una instalación existente, usar [upgrade WA01](docs/wa01-produccion-distribuida-wazuh-4.14.8.md#actualizar-soc-operations-sin-reinstalar-wa01),
no `apply`, inicialización de OpenBao ni borrado de volúmenes. El upgrade no ofrece rollback
global automático. Actualizar primero el agente si el Manager está en otro servidor.
Conservar respaldos y releases anteriores. La guía incorpora la parada SIGINT verificada en WA01.

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

1. Descargar `soc-operations-0.1.161.tar.gz.age` y `SHA256SUMS` desde Releases.
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

- El primer `soc_engineering` define su contraseña mediante un prompt oculto durante `resume`.
- No se genera un correo de activación inicial.
- SMTP se configura después desde la interfaz para los usuarios posteriores.
- El instalador no abre puertos ni modifica UFW, nftables o iptables.
- La clave privada de distribución se custodia bajo `SOC Operations Installer Descifrado` en el
  gestor de secretos autorizado; su valor y los secretos del servidor permanecen fuera de GitHub.
- Wazuh 4.12 no es compatible con este paquete; consulte la
  [matriz de compatibilidad](docs/compatibility.md).

Consulte [SECURITY.md](SECURITY.md) antes de reportar una vulnerabilidad.
