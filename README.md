# SOC Operations Installer

Repositorio público de distribución del instalador SOC Operations para Wazuh 4.14.7, en perfil
AIO o distribuido con un único Dashboard.

El código fuente y el paquete sin cifrar no se publican aquí. Cada versión se distribuye como un
asset cifrado de GitHub Releases y requiere una identidad privada `age`. La identidad se recupera
únicamente desde el gestor de secretos autorizado, entrada `SOC Operations Installer Descifrado`.

## Versión vigente

- Release: `v0.1.150`
- Instalador: `0.1.150`
- API, worker y agente: `0.1.111`
- Plugin: `socOperations@0.1.93`
- Wazuh requerido: `4.14.7-1`
- OpenSearch Dashboards requerido: `2.19.5`

`0.1.150` exige evidencia verificable de que la contraseña inicial del primer ingeniero fue
aplicada. Si una reinstalación conserva un marcador antiguo, `resume` vuelve a mostrar el prompt
oculto y reemplaza la contraseña mediante mTLS con auditoría. También incorpora un comando local
de recuperación y conserva la corrección de propiedad de los puertos `8443`/`9443`.

## Uso

1. Descargar `soc-operations-0.1.150.tar.gz.age` desde Releases.
2. Recuperar la clave privada `age` desde el gestor de secretos autorizado, entrada
   `SOC Operations Installer Descifrado`. Nunca se publica en este repositorio.
3. Seguir [Instalación AIO](docs/installation.md) o
   [instalación distribuida](docs/distributed-installation.md). Ambas guías incluyen el bloqueo
   previo de actualizaciones Wazuh, límites iniciales de memoria y baseline de shards/réplicas.
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
