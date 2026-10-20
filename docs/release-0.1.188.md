# SOC Operations 0.1.188


Instalador 0.1.188; API interna, API externa, worker y agente 0.1.131;
plugin socOperations 0.1.111 para OSD 2.19.5 y 2.19.6. Esquema c8d3e902f751,
sin nuevas migraciones. Perfiles Wazuh 4.14.7-1 y 4.14.8-1 respectivamente.

Filtros: campo != valor significa excluir coincidencias. Un campo ausente,
nulo o vacio ya no descarta la alerta por esa exclusion. En arrays basta
una coincidencia para excluir. Los otros operadores siguen exigiendo valores;
se conservan los requisitos AND, nivel, grupos, aislamiento tenant y deduplicacion.
No se crean aliases entre campos ni se reprocesan alertas historicas.

Certificados: la validacion verifica cadena, proposito, IP y DNS mediante
openssl verify, no el codigo de salida de x509 -checkip/-checkhost. Se aplica
en generacion nueva, reutilizacion, importacion y renovacion del servicio/GeoIP
y en los flujos PKI corregidos. La recuperacion de material vencido omite
solo la fecha del material anterior; no omite identidad, claves ni proposito.
Una identidad incorrecta detiene la operacion; no se reescriben certificados
silenciosamente ni se desactiva TLS.

Incluye los correctivos locales posteriores a 0.1.185: bloqueos privados en
/run/soc-operations-locks, root:root 0700 y archivos 0600; rechazo de enlaces,
objetos especiales y permisos inseguros; claves cliente root:10001 0440 y
servidor root:www-data 0440. No se cambian permisos globales de /run/lock.

Renovacion mTLS local: timer cada seis horas, anticipacion siete dias,
vigencia 30 dias, diario y copia privados, validacion y recuperacion ante fallo.
Recrea api/external-api/worker para actualizar montajes y comprueba mTLS,
readiness y estado de API externa. Puede haber una interrupcion breve.
Solo se coordina automaticamente cuando Manager/agente y runtime estan en
el mismo host con Compose/montajes aprobados. Si estan separados requiere
coordinacion remota; no se distribuyen credenciales automaticamente.

Imagen, wheel y ambos plugins recompilados; no se reutiliza la imagen anterior
para la nueva logica. No cambian endpoints, alcances API, RBAC, puertos ni UFW.
No modifica auto-unseal ni TLS publico. Conserva las transiciones aprobadas
de versiones anteriores; no acepta Compose arbitrarios.

Solo publicar TAR cifrado, hashes y documentacion publica. El descifrado
requiere la identidad autorizada. Publicar no actualiza ningun servidor.
Los candidatos locales 0.1.186/0.1.187 no son pasos previos obligatorios.
Consultar release-manifest.json para resultados, huellas y limites efectivos.

## Integridad y validación

- Instalador cifrado SHA-256: `f3b590d85c2959c10890d52cf8476b932a8afee6cd4240f6f8b3d7f22d439cb0`.
- TAR claro: `5319d50a4b6fbfdb626b1c8ee9f940e44a969e266f225fadb4f0d9000ba4285f`.
- Orquestador: `89a52aecc9863eb1d634a36e5045e8fb876dbb315b714518cc1069d7c6cf7cb9`.
- Compose: `321c80c77b83debfd1bd934fad9871c850dd4bdd81d9980d36337828e1537445`.
- Imagen config ID: `sha256:32b0cb8427eac76d6dd6925a21b907c7e2164fd3524dd63c94a315734f54c1e7`.
- Imagen OCI manifest ID: `sha256:93e2db752c69c8be95f469052d00215e028f8575e1f5bc3d1eca4a78a0319436`.

El TAR contiene 49 archivos regulares planos, incluido SHA256SUMS. Solo se publican el
asset cifrado, manifiesto de hashes y documentación pública. El destinatario age no cambia;
el descifrado final lo realiza el destinatario autorizado. No se utilizó su identidad privada
para construir este paquete. Los hashes no sustituyen la autenticidad del canal.

Validación local: **1994 pruebas aprobadas**
(1676 backend/agente y 318 interfaz), sin fallos ni omisiones;
TypeScript y compilación nueva de ambos perfiles, mypy en 123 archivos y Ruff aprobados.
Incluye 56 casos de filtros negativos y 27 casos de identidad TLS. Los subconjuntos repetidos
no se suman dos veces. Fuente/wheel/imagen contrastados en 122 archivos Python y 58 de
migración/configuración; pip check aprobado. Entry point externo real aislado: salud 200,
ocho rutas sin clave 401 y escrituras rechazadas 405, no root, raíz read-only y sin red externa.

Las pruebas PostgreSQL/RLS usan datos sintéticos. La validación Linux repetida con la imagen
nueva usa OpenSSL, HTTPS/mTLS y permisos POSIX reales; simula Compose, systemd y recargas nginx.
Comprueba generación/reutilización, ocho rechazos IP/DNS sin mutación, recuperación de cadena
vencida y restauración ante fallo de recarga. La auditoría de objetos maliciosos de bloqueo
del código conservado proviene de la validación anterior; se repiten sus regresiones Python.
Las pruebas de generación no son una instalación Wazuh completa.
La interfaz se comprueba con DOM automatizado, no contra el navegador productivo.
ShellCheck no introduce hallazgos respecto a 0.1.187; persisten advertencias previas.

No se ha ejecutado esta actualización ni una renovación en producción. Mantener respaldo
vigente y completar la [aceptación del destino](upgrade-0.1.188.md). No hay garantía de
cero interrupción. No restaurar automáticamente ni desactivar los controles ante un fallo.
