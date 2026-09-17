# Descarga, descifrado e instalación

## 1. Requisitos

El perfil WA001 exige:

- Ubuntu 24.04;
- dirección interna `10.0.0.10`;
- Wazuh `4.14.7-1` all-in-one;
- OpenSearch Dashboards `2.19.5`;
- acceso root mediante `sudo`;
- una copia autorizada de la identidad privada `age`.

El instalador no adapta automáticamente estas versiones o direcciones.

## 2. Descargar el asset cifrado

Descargue desde el Release `v0.1.100`:

```text
soc-operations-0.1.100.tar.gz.age
```

No descargue instaladores desde comentarios, forks no autorizados o enlaces externos.

### Descarga directa desde Ubuntu

El asset oficial es un `tar.gz` cifrado con `age`.
Los siguientes pasos presuponen que la sesión SSH actual ya tiene un shell de `root`. Compruébelo
y descargue el asset junto con su archivo de hashes:

```bash
test "$(id -u)" -eq 0
apt-get update
apt-get install -y curl ca-certificates age

mkdir -p /root/soc-installer
cd /root/soc-installer

curl --fail --location --remote-name \
  https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.100/soc-operations-0.1.100.tar.gz.age

curl --fail --location --remote-name \
  https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.100/SHA256SUMS
```

Verifique el asset cifrado antes de usarlo:

```bash
grep 'soc-operations-0.1.100.tar.gz.age$' SHA256SUMS | sha256sum --check
```

El resultado debe ser:

```text
soc-operations-0.1.100.tar.gz.age: OK
```

Obtenga la identidad privada desde el vault **SocOperation Installer Key** y colóquela
temporalmente en `/root/soc-operations-installer-key.txt`. La identidad nunca debe descargarse
desde GitHub:

```bash
chmod 600 /root/soc-operations-installer-key.txt

age --decrypt \
  --identity /root/soc-operations-installer-key.txt \
  --output soc-operations-0.1.100.tar.gz \
  soc-operations-0.1.100.tar.gz.age

sha256sum --check SHA256SUMS
tar -xzf soc-operations-0.1.100.tar.gz
find release-0.1.100 -maxdepth 1 -type f | wc -l
```

La verificación debe mostrar ambos archivos como `OK` y el conteo final debe ser `19`. Cuando la
política de custodia no permita conservar la identidad en el servidor, elimine su copia temporal
después de confirmar la extracción:

```bash
rm -f /root/soc-operations-installer-key.txt
```

## 3. Preparar un Ubuntu limpio e instalar Wazuh

Conéctese por SSH y obtenga un shell de `root`:

```bash
cat /etc/os-release
ip -brief address
dpkg-query -W wazuh-manager wazuh-indexer wazuh-dashboard filebeat 2>&1 || true
systemctl is-active wazuh-manager wazuh-indexer wazuh-dashboard filebeat 2>/dev/null || true
```

El host debe ejecutar Ubuntu 24.04, tener la dirección interna `10.0.0.10` y no contener una
instalación parcial de Wazuh. Si alguna de esas condiciones no se cumple, no continúe.

Prepare la cuenta técnica y descargue el asistente oficial fijado a la rama 4.14:

```bash
set -euo pipefail
id codex-lab >/dev/null 2>&1 || \
  adduser --disabled-password --gecos '' codex-lab
usermod --shell /bin/bash codex-lab
passwd --lock codex-lab
install -d -o codex-lab -g codex-lab -m 0750 /home/codex-lab/staging

curl --fail --location --proto '=https' --tlsv1.2 \
  --output /home/codex-lab/staging/wazuh-install.sh \
  https://packages.wazuh.com/4.14/wazuh-install.sh

chown root:root /home/codex-lab/staging/wazuh-install.sh
chmod 0755 /home/codex-lab/staging/wazuh-install.sh
bash -n /home/codex-lab/staging/wazuh-install.sh
head -n 1 /home/codex-lab/staging/wazuh-install.sh
sha256sum /home/codex-lab/staging/wazuh-install.sh
```

`bash -n` debe terminar sin errores y el primer renglón debe ser un shebang de Bash. Registre la
huella obtenida y ejecute la instalación all-in-one:

```bash
cd /root
bash /home/codex-lab/staging/wazuh-install.sh -a
```

Guarde en un gestor seguro la contraseña de `admin` que muestra el asistente. No publique esa
contraseña ni `wazuh-install-files.tar` en GitHub, chats, tickets o registros.

El asistente puede crear `wazuh-install-files.tar` en `/root` o junto al script en `staging`.
Localícelo, consérvelo en `/root` y restrinja sus permisos:

```bash
if [ -f /home/codex-lab/staging/wazuh-install-files.tar ]; then
  mv /home/codex-lab/staging/wazuh-install-files.tar /root/wazuh-install-files.tar
fi

if [ -f /home/codex-lab/staging/wazuh-install.sh ]; then
  mv /home/codex-lab/staging/wazuh-install.sh /root/wazuh-install.sh
fi

test -f /root/wazuh-install-files.tar
chown root:root /root/wazuh-install-files.tar
chmod 0600 /root/wazuh-install-files.tar
chown root:root /root/wazuh-install.sh
chmod 0755 /root/wazuh-install.sh
ls -l /root/wazuh-install-files.tar
```

El resultado debe mostrar propietario `root:root` y permisos `-rw-------`. No vuelva a ejecutar el
instalador de Wazuh solamente para cambiar la ubicación del archivo. Retirarlo de `staging` evita
mezclarlo con los 19 archivos del release de SOC Operations.

Compruebe la instalación:

```bash
dpkg-query -W -f='${Package}\t${Version}\n' \
  wazuh-manager wazuh-indexer wazuh-dashboard filebeat
systemctl is-active wazuh-manager wazuh-indexer wazuh-dashboard filebeat
ip -brief address
ss -lntH | grep -E ':(443|1514|1515|9200|55000)[[:space:]]'
```

Los paquetes `wazuh-manager`, `wazuh-indexer` y `wazuh-dashboard` deben mostrar `4.14.7-1`; los
cuatro servicios deben estar activos y el servidor debe conservar `10.0.0.10`. Los listeners
esperados son `443`, `1514`, `1515`, `9200` y `55000`.

No habilite UFW todavía. Las reglas de red se aplican manualmente, después de preservar primero
el acceso por el puerto SSH administrativo.

## 4. Colocar el release en staging

La cuenta `codex-lab` ya fue creada en la sección anterior. Compruebe que existe y que `staging`
no contiene el asistente ni el archivo privado de Wazuh:

```bash
id codex-lab
install -d -o codex-lab -g codex-lab -m 0750 /home/codex-lab/staging
find /home/codex-lab/staging -mindepth 1 -maxdepth 1 -print
```

El último comando no debe mostrar archivos antes de copiar el release. La descarga y extracción
directa de la sección 2 creó este directorio:

```text
/root/soc-installer/release-0.1.100
```

Copie su contenido a `staging`:

```bash
test -d /root/soc-installer/release-0.1.100
cp -a /root/soc-installer/release-0.1.100/. /home/codex-lab/staging/
```

Normalice la propiedad y valide el contenido:

```bash
chown -R root:root /home/codex-lab/staging
find /home/codex-lab/staging -maxdepth 1 -type f | sort
test "$(find /home/codex-lab/staging -maxdepth 1 -type f | wc -l)" -eq 19
```

El staging debe contener exactamente los 19 archivos del release, sin renombrarlos.

## 5. Ejecutar el instalador

```bash
install -o root -g root -m 0755 \
  /home/codex-lab/staging/soc-operations-install \
  /usr/local/sbin/soc-operations-install

sha256sum /usr/local/sbin/soc-operations-install
```

Hash esperado:

```text
4b21b31e3f27f99fa510003af946396f8566144b96182498d01924a112e6a765
```

### Reanudar una instalación detenida en `v0.1.99`

`v0.1.99` podía detenerse en el paso `runtime` con `compose checksum mismatch`. No ejecute
rollback ni reinstale Wazuh. Descargue `v0.1.100`, reemplace los 19 archivos de `staging`, vuelva
a instalar el orquestador y repita `apply` con exactamente el mismo correo y nombre. Los pasos ya
completados se omiten de forma segura.

Después: Reemplazar "INGENIERO@EMPRESA.COM" y "Primer ingeniero SOC"

```bash
/usr/local/sbin/soc-operations-install preflight

/usr/local/sbin/soc-operations-install apply \
  --email INGENIERO@EMPRESA.COM \
  --display-name "Primer ingeniero SOC"
```

`apply` debe terminar en `phase=waiting_for_openbao_custody`.

El instalador no modifica el firewall. Antes de `resume`, valide subnet, gateway e interfaz y
aplique manualmente las reglas aprobadas descritas en [Referencia de firewall](firewall-reference.md).

## 6. OpenBao y primer usuario

```bash
/usr/local/sbin/soc-operations-install openbao-init
/usr/local/sbin/soc-operations-install status
/usr/local/sbin/soc-operations-install resume
```

Antes de `resume` debe existir la regla interna del bridge descrita en
[Referencia de firewall](firewall-reference.md). Si el proceso se detiene con
`identity_agent: unavailable`, siga allí la prueba mTLS desde el contenedor y el procedimiento de
recuperación. No repita `apply`, `openbao-init` ni ejecute rollback para ese caso.

Durante `resume` se solicitarán de forma oculta:

1. el token raíz inicial de OpenBao;
2. la contraseña del primer ingeniero;
3. la confirmación de esa contraseña.

La contraseña debe tener 14–256 caracteres y al menos tres clases entre minúsculas, mayúsculas,
números y símbolos. No se acepta como argumento y no se guarda en archivos.

El estado final esperado incluye:

```text
phase=complete
dashboard=302
soc_api_liveness=200
soc_api_readiness=200
openbao_initialized=true
openbao_sealed=false
```

Inicie sesión directamente con el correo indicado en `apply`. Después configure SMTP desde
**Administración → Integraciones** para habilitar las invitaciones de usuarios posteriores.

## 7. Puertos y ejemplo UFW

El instalador no habilita UFW ni modifica el firewall. La matriz de entrada recomendada para
WA001 es:

| Puerto destino | Origen recomendado | Uso |
| --- | --- | --- |
| `PUERTO_SSH/TCP` | Red o estaciones administrativas | SSH |
| `10.0.0.10:443/TCP` | HAProxy `192.168.4.50/32` y VPN autorizada | Wazuh Dashboard |
| `10.0.0.10:9443/TCP` | Solo HAProxy `192.168.4.50/32` | API externa de solo lectura |
| `10.0.0.10:1514/TCP` | HAProxy de agentes o redes de endpoints | Eventos Wazuh |
| `10.0.0.10:1515/TCP` | HAProxy de agentes o redes de endpoints | Enrolamiento Wazuh |
| `172.19.0.1:8443/TCP` | Solo bridge Docker `172.19.0.0/16` | Agente mTLS interno |

No publique `8080`, `8091`, `8200`, `9000`, `9200`, `5432` ni `55000`. Si se requiere exponer la
API administrativa Wazuh de `55000`, trátelo como una excepción independiente con autenticación,
TLS y allowlist aprobados; no forma parte de este despliegue estándar.

Antes de aplicar el ejemplo, ajuste interfaz, puerto SSH y redes. Mantenga abierta la sesión SSH
actual y valide una segunda conexión antes de habilitar UFW. Siempre que sea posible, reduzca
`RED_ADMIN` a la IP exacta de administración con máscara `/32`:

```bash
INTERFAZ_SERVICIO=ens19
PUERTO_SSH=11050
RED_ADMIN=192.168.4.0/24
IP_HAPROXY=192.168.4.50
RED_ENDPOINTS=10.0.0.0/24
RED_VPN=10.81.0.0/16
IP_WA001=10.0.0.10

ufw allow in on "$INTERFAZ_SERVICIO" \
  from "$RED_ADMIN" to "$IP_WA001" port "$PUERTO_SSH" proto tcp \
  comment 'SSH administration'

ufw allow in on "$INTERFAZ_SERVICIO" \
  from "$IP_HAPROXY" to "$IP_WA001" port 443 proto tcp \
  comment 'Wazuh Dashboard from HAProxy'

ufw allow in on "$INTERFAZ_SERVICIO" \
  from "$IP_HAPROXY" to "$IP_WA001" port 9443 proto tcp \
  comment 'SOC external API from HAProxy'

ufw allow in on "$INTERFAZ_SERVICIO" \
  from "$RED_VPN" to "$IP_WA001" port 443 proto tcp \
  comment 'Wazuh Dashboard from VPN'
```

Para agentes publicados exclusivamente mediante HAProxy, permita solo su dirección de origen:

```bash
ufw allow in on "$INTERFAZ_SERVICIO" \
  from "$IP_HAPROXY" to "$IP_WA001" port 1514 proto tcp \
  comment 'Wazuh events from HAProxy'

ufw allow in on "$INTERFAZ_SERVICIO" \
  from "$IP_HAPROXY" to "$IP_WA001" port 1515 proto tcp \
  comment 'Wazuh enrollment from HAProxy'
```

Si los endpoints llegan directamente a WA001, use en su lugar las redes aprobadas; no aplique
ambas modalidades sin necesidad:

```bash
for RED_AGENTES in "$RED_ENDPOINTS" "$RED_VPN"; do
  ufw allow in on "$INTERFAZ_SERVICIO" \
    from "$RED_AGENTES" to "$IP_WA001" port 1514 proto tcp \
    comment 'Wazuh direct agent events'

  ufw allow in on "$INTERFAZ_SERVICIO" \
    from "$RED_AGENTES" to "$IP_WA001" port 1515 proto tcp \
    comment 'Wazuh direct agent enrollment'
done
```

La regla interna `172.19.0.0/16 → 172.19.0.1:8443` debe crearse con el bloque de validación
dinámica de [Referencia de firewall](firewall-reference.md); no copie manualmente un nombre
`br-*` de otro servidor.

Revise las reglas antes de habilitar el firewall:

```bash
ufw show added
ufw status verbose
```

Solo después de validar las reglas y una segunda sesión SSH, si la política del servidor requiere
UFW activo, habilítelo explícitamente y vuelva a comprobar acceso y servicios:

```bash
ufw enable
ufw status numbered
ss -lntH | grep -E ':(443|9443|1514|1515|8443)[[:space:]]'
```
