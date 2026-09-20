# Instalación limpia de SOC Operations 0.1.142

Esta guía instala SOC Operations sobre un servidor all-in-one de Wazuh ya operativo. El
instalador no instala ni actualiza Wazuh, no modifica el firewall y no está soportado sobre una
instalación parcial o una versión distinta de la indicada.

## 1. Requisitos

- Ubuntu Server 24.04;
- Wazuh Manager, Indexer y Dashboard `4.14.7-1` en el mismo servidor;
- OpenSearch Dashboards `2.19.5`;
- acceso administrativo mediante `sudo`;
- salida HTTPS hacia GitHub y los repositorios oficiales de Ubuntu/Wazuh;
- FQDN HTTPS definitivo de Wazuh Dashboard;
- dirección IPv4 interna del AIO y, si existe, CIDR del reverse proxy/HAProxy;
- identidad privada `age` entregada por un canal protegido.

El release `0.1.142` no es compatible con Wazuh 4.12. El `preflight` lo rechaza antes de instalar
componentes. No modifique esa comprobación; consulte [Compatibilidad](compatibility.md).

La instalación limpia supone un host nuevo o restaurado. Si existen datos anteriores de SOC
Operations, respáldelos y ejecute una restauración controlada; no borre manualmente
`/var/lib/soc-operations-installer`, PostgreSQL u OpenBao para forzar una reinstalación.

## 2. Instalar y validar Wazuh 4.14.7

Compruebe primero que no existe una instalación parcial:

```bash
cat /etc/os-release
ip -brief address
dpkg-query -W wazuh-manager wazuh-indexer wazuh-dashboard filebeat 2>&1 || true
systemctl is-active wazuh-manager wazuh-indexer wazuh-dashboard filebeat 2>/dev/null || true
```

En un Ubuntu limpio, descargue y revise el asistente oficial fijado a la rama 4.14 antes de
ejecutarlo:

```bash
sudo -i
set -euo pipefail

install -d -o root -g root -m 0700 /root/wazuh-install
cd /root/wazuh-install
curl --fail --location --proto '=https' --tlsv1.2 \
  --output wazuh-install.sh \
  https://packages.wazuh.com/4.14/wazuh-install.sh
chmod 0755 wazuh-install.sh
bash -n wazuh-install.sh
sha256sum wazuh-install.sh
bash ./wazuh-install.sh -a
```

Guarde en un gestor seguro la contraseña de `admin` y el archivo
`wazuh-install-files.tar`. Este último contiene credenciales y certificados: manténgalo con modo
`0600`, fuera de GitHub, chats y tickets.

Antes de continuar, confirme las versiones y servicios:

```bash
dpkg-query -W -f='${Package}\t${Version}\n' \
  wazuh-manager wazuh-indexer wazuh-dashboard filebeat
systemctl is-active wazuh-manager wazuh-indexer wazuh-dashboard filebeat
ss -lntH | grep -E ':(443|1514|1515|9200|55000)[[:space:]]'
```

Manager, Indexer y Dashboard deben mostrar `4.14.7-1`; los cuatro servicios deben estar activos.

## 3. Descargar y verificar el release cifrado

Ejecute como `root`:

```bash
apt-get update
apt-get install -y age ca-certificates curl
install -d -o root -g root -m 0700 /root/soc-installer
cd /root/soc-installer

curl --fail --location --remote-name \
  https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.142/soc-operations-0.1.142.tar.gz.age
curl --fail --location --remote-name \
  https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.142/SHA256SUMS

grep 'soc-operations-0.1.142.tar.gz.age$' SHA256SUMS | sha256sum --check
```

El resultado debe ser:

```text
soc-operations-0.1.142.tar.gz.age: OK
```

Obtenga la identidad privada desde el almacén autorizado y colóquela temporalmente en
`/root/soc-operations-installer-key.txt`. Nunca la descargue desde GitHub:

```bash
chmod 0600 /root/soc-operations-installer-key.txt
age --decrypt \
  --identity /root/soc-operations-installer-key.txt \
  --output soc-operations-0.1.142.tar.gz \
  soc-operations-0.1.142.tar.gz.age

sha256sum --check SHA256SUMS
tar -xzf soc-operations-0.1.142.tar.gz
cd release-0.1.142
sha256sum --check SHA256SUMS
test "$(find . -maxdepth 1 -type f | wc -l)" -eq 25
```

La primera verificación valida el asset cifrado y el TAR; la segunda valida los 24 artefactos del
release. El directorio contiene 25 archivos en total porque incluye su propio `SHA256SUMS`.

Si la política no permite conservar la identidad en el servidor, elimine únicamente su copia
temporal después del descifrado:

```bash
rm -f /root/soc-operations-installer-key.txt
```

## 4. Ejecutar el preflight

Desde `/root/soc-installer/release-0.1.142` instale solo el orquestador:

```bash
install -o root -g root -m 0755 \
  ./soc-operations-install \
  /usr/local/sbin/soc-operations-install

sha256sum /usr/local/sbin/soc-operations-install
```

La huella esperada es:

```text
e041686aea8099a64a6d3d44338691e3b31e5243fe0924f074d9f493ead920bc
```

Ejecute la validación sin cambios persistentes:

```bash
sudo /usr/local/sbin/soc-operations-install preflight \
  --staging-root /root/soc-installer/release-0.1.142
```

En un host con varias interfaces, añada `--service-address IP_INTERNA`. No continúe si falla una
versión, servicio, dirección o hash.

## 5. Aplicar la fase técnica

Reemplace los valores de ejemplo:

```bash
sudo /usr/local/sbin/soc-operations-install apply \
  --staging-root /root/soc-installer/release-0.1.142 \
  --service-address IP_INTERNA_AIO \
  --external-proxy-cidr IP_O_CIDR_DEL_PROXY \
  --email INGENIERO@EMPRESA.COM \
  --display-name "Primer ingeniero SOC" \
  --public-url https://dashboard.example.com
```

`--service-address` puede omitirse si la ruta predeterminada identifica la IP correcta.
`--external-proxy-cidr` puede omitirse si la API externa debe permanecer accesible solo desde
loopback. `--public-url` debe ser un origen HTTPS sin ruta, consulta ni fragmento.

La fase es reanudable. Si se interrumpe, corrija la causa y repita el mismo comando con la misma
identidad; no elimine el estado. El resultado esperado es:

```text
phase=waiting_for_openbao_custody
```

Antes de `resume`, aplique y pruebe las reglas aprobadas de
[firewall](firewall-reference.md), incluida la ruta del bridge Docker hacia el agente mTLS.

## 6. Inicializar OpenBao y custodiar las credenciales

En una instalación nueva ejecute una sola vez:

```bash
sudo /usr/local/sbin/soc-operations-install openbao-init
```

El comando genera cinco recovery shares y un token raíz inicial. Debe custodiar fuera del servidor:

1. las cinco recovery shares, distribuidas entre custodios;
2. el token raíz inicial en un almacén offline;
3. una copia cifrada y externa de
   `/etc/soc-operations-lab/openbao/auto-unseal.key`, en una custodia separada.

No copie estos valores en argumentos, historial del shell, GitHub, chats o tickets. La clave
`auto-unseal.key` permite el arranque automático, pero no reemplaza el token raíz ni las recovery
shares. Si se pierde el token raíz, tres shares permiten generar otro; si también se pierden las
shares, el almacén actual no puede administrarse ni recuperarse.

Compruebe el estado:

```bash
sudo /usr/local/sbin/soc-operations-install status
```

Debe indicar:

```text
openbao_initialized=true
openbao_sealed=false
phase=waiting_for_openbao_configuration
```

No ejecute `openbao-unseal` en una instalación nueva con auto-unseal.

## 7. Completar la instalación

```bash
sudo /usr/local/sbin/soc-operations-install resume
```

El proceso solicita de forma oculta:

1. el token raíz inicial de OpenBao;
2. la contraseña del primer ingeniero;
3. la confirmación de esa contraseña.

La contraseña debe tener entre 14 y 256 caracteres y al menos tres clases entre minúsculas,
mayúsculas, números y símbolos. El primer ingeniero queda activo y no recibe invitación por
correo; inicie sesión directamente con el correo y la contraseña definidos.

Valide el resultado:

```bash
sudo /usr/local/sbin/soc-operations-install status
```

La salida final debe incluir:

```text
installer_version=0.1.142
phase=complete
dashboard=302
soc_api_liveness=200
soc_api_readiness=200
openbao_initialized=true
openbao_sealed=false
```

Después del primer acceso configure SMTP y los demás canales desde **SOC Operations →
Administración → Integraciones**. Las invitaciones y restablecimientos posteriores dependen de una
integración de correo funcional.

## 8. Reinicio y aceptación mínima

Reinicie el AIO durante la ventana de prueba y confirme que OpenBao vuelve sin introducir shares:

```bash
sudo reboot
```

Al regresar:

```bash
sudo /usr/local/sbin/soc-operations-install status
curl -sS http://127.0.0.1:8200/v1/sys/health
```

Además, valide un usuario de ingeniería, un tenant de prueba, aislamiento entre tenants, creación
de caso, vulnerabilidades, reporte y envío SMTP. Una instalación técnica no debe promoverse a
producción hasta completar estas pruebas y un simulacro de
[respaldo y restauración](backup-and-restore.md).

## 9. Evidencia segura ante fallos

Puede compartir, después de revisar la salida:

```bash
sudo /usr/local/sbin/soc-operations-install status
sudo docker compose --project-name soc-operations-wa001 \
  --env-file /etc/soc-operations-lab/runtime.env \
  --file /opt/soc-operations-lab/docker-compose.yml ps
sudo docker compose --project-name soc-operations-wa001 \
  --env-file /etc/soc-operations-lab/runtime.env \
  --file /opt/soc-operations-lab/docker-compose.yml \
  logs --no-color --tail 120 api external-api openbao
sudo journalctl --no-pager -u wazuh-dashboard -u wazuh-manager -n 120
```

No comparta `runtime.env`, tokens, recovery shares, claves privadas, el pepper,
`auto-unseal.key`, credenciales Wazuh ni `wazuh-install-files.tar`.
