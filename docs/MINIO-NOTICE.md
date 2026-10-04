# MinIO recuperado para SOC Operations

Se incluye una copia sin modificaciones exportada del laboratorio anterior para que el
instalador pueda cargarla localmente sin descargar MinIO desde Quay. Se distribuye dentro
del paquete cifrado destinado a los operadores autorizados. No incluye volúmenes, usuarios,
credenciales ni evidencias del laboratorio.

## Identificación y procedencia

- Versión: `RELEASE.2025-07-23T15-54-02Z`.
- Plataforma incluida y comprobada: `linux/amd64`; no se declara soporte ARM.
- Archivo: `soc-operations-minio-image.tar.gz`.
- SHA-256 del archivo: `2223b43be55458a29e8add829dbcd0cc0fda68872c104df6f5e475144b492598`.
- Índice OCI original: `sha256:d249d1fb6966de4d8ad26c04754b545205ff15a62e4fd19ebd0f26fa5baacbc0`.
- Configuración amd64: `sha256:a98a9d647e700e45c1d3d2e44709f23952a39c199731d84e623eb558fd5501f4`.
- Etiqueta local de instalación: `soc-operations-minio:RELEASE.2025-07-23T15-54-02Z`.
- Cliente `mc` incluido en la imagen: `RELEASE.2025-07-21T05-28-08Z`.

## Licencias y fuentes

MinIO y su cliente mc conservan sus licencias AGPLv3. La imagen conserva los avisos originales,
incluidos `/licenses/LICENSE` y `/licenses/CREDITS`. El paquete incorpora además la licencia,
los créditos y las fuentes upstream de las versiones identificadas:

- `minio-LICENSE.txt` y `minio-CREDITS.txt`.
- `minio-RELEASE.2025-07-23T15-54-02Z-source.tar.gz`.
- `mc-LICENSE.txt`.
- `mc-RELEASE.2025-07-21T05-28-08Z-source.tar.gz`.

Las fuentes incluyen los archivos de módulos y las instrucciones upstream de construcción;
las dependencias transitivas no están vendorizadas. Los avisos no sustituyen las obligaciones
de licencia. La distribución y cualquier modificación posterior deben conservar los avisos
y asegurar el acceso al código fuente correspondiente, incluidas las dependencias exigibles.
La base UBI y las demás herramientas mantienen sus propios términos.

Referencias de procedencia:

- https://github.com/minio/minio/tree/RELEASE.2025-07-23T15-54-02Z
- https://github.com/minio/mc/tree/RELEASE.2025-07-21T05-28-08Z
- https://www.redhat.com/en/about/red-hat-end-user-license-agreements#UBI

## Evaluación pendiente

**La recuperación y la verificación de integridad no constituyen una aprobación para
producción.** MinIO Community declara que ya no se mantiene. Esta copia no recibe
automáticamente actualizaciones, parches ni soporte del proveedor.

Antes de aprobar su uso, evaluar vulnerabilidades del servidor, cliente y sistema base;
aislamiento de tenants; permisos; cifrado y custodia de claves; versionado y cadena de
custodia; capacidad; y respaldo y restauración de evidencias. Las comprobaciones locales
de arranque y operaciones S3 no certifican estos controles ni los objetivos RPO/RTO.

El instalador conserva los volúmenes y las claves existentes. Esta recuperación no debe
utilizarse para importar los datos ni los secretos del laboratorio a producción.
