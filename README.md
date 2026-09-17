# SOC Operations Installer

Repositorio público de distribución del instalador SOC Operations para el perfil WA001.

El código fuente y el paquete sin cifrar no se publican aquí. Cada versión se distribuye como un
asset cifrado de GitHub Releases y requiere una identidad privada `age` entregada por un canal
separado.

## Versión vigente

- Release: `v0.1.98`
- Instalador: `0.1.98`
- API, worker y agente: `0.1.80`
- Plugin: `socOperations@0.1.64`
- Wazuh requerido: `4.14.7-1`
- OpenSearch Dashboards requerido: `2.19.5`

## Uso

1. Descargar `soc-operations-0.1.98.tar.gz.age` desde Releases.
2. Obtener la clave privada `age` por el canal autorizado. Nunca se publica en este repositorio.
3. Seguir [Descarga, descifrado e instalación](docs/installation.md).
4. Aplicar manualmente la política de red descrita en [Referencia de firewall](docs/firewall-reference.md).

Los scripts en `scripts/` verifican primero SHA-256, descifran el asset y vuelven a validar el TAR
antes de extraerlo.

## Modelo de seguridad

- El primer `soc_engineering` define su contraseña mediante un prompt oculto durante `resume`.
- No se genera un correo de activación inicial.
- SMTP se configura después desde la interfaz para los usuarios posteriores.
- El instalador no abre puertos ni modifica UFW, nftables o iptables.
- La clave privada de distribución y los secretos del servidor permanecen fuera de GitHub.

Consulte [SECURITY.md](SECURITY.md) antes de reportar una vulnerabilidad.

