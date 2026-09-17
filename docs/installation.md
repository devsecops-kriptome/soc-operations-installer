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

Descargue desde el Release `v0.1.98`:

```text
soc-operations-0.1.98.tar.gz.age
```

No descargue instaladores desde comentarios, forks no autorizados o enlaces externos.

## 3. Descifrar y verificar en Windows

Instale `age`:

```powershell
winget install --id FiloSottile.age --exact
```

Abra una nueva terminal después de instalar `age`. Desde la raíz de este repositorio ejecute:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File ".\scripts\decrypt-and-verify.ps1" `
  -Asset "$HOME\Downloads\soc-operations-0.1.98.tar.gz.age" `
  -Identity "$HOME\.config\age\soc-operations-installer-key.txt" `
  -OutputDirectory "$HOME\Downloads\soc-operations-0.1.98"
```

El resultado debe contener `release-0.1.98` con exactamente 19 archivos.

En Linux puede usarse `scripts/decrypt-and-verify.sh`.

## 4. Preparar Wazuh

Antes de SOC Operations, instale Wazuh all-in-one 4.14 y compruebe:

```bash
dpkg-query -W wazuh-manager wazuh-indexer wazuh-dashboard filebeat
systemctl is-active wazuh-manager wazuh-indexer wazuh-dashboard filebeat
ip -brief address
```

Los tres paquetes Wazuh deben mostrar `4.14.7-1`, los cuatro servicios deben estar activos y el
servidor debe tener `10.0.0.10`.

Conserve fuera de GitHub la contraseña de `admin` y `/root/wazuh-install-files.tar`.

## 5. Copiar el release al servidor

Cree la cuenta técnica y el staging:

```bash
sudo adduser --disabled-password --gecos '' codex-lab
sudo usermod --shell /bin/bash codex-lab
sudo passwd --lock codex-lab
sudo install -d -o codex-lab -g codex-lab -m 0750 /home/codex-lab/staging
```

En el servidor cree primero el directorio de carga:

```bash
mkdir -p "$HOME/soc-release-upload"
chmod 700 "$HOME/soc-release-upload"
```

Desde Windows, ajuste usuario, dirección, puerto y clave. Copie el directorio completo:

```powershell
scp -P PUERTO_SSH -i "$HOME\.ssh\CLAVE_PRIVADA" -r `
  "$HOME\Downloads\soc-operations-0.1.98\release-0.1.98" `
  USUARIO_SSH@IP_DEL_SERVIDOR:~/soc-release-upload/
```

En el servidor:

```bash
sudo cp -a "$HOME/soc-release-upload/release-0.1.98/." /home/codex-lab/staging/
find /home/codex-lab/staging -maxdepth 1 -type f | wc -l
```

El staging del release debe contener los 19 archivos sin renombrarlos.

## 6. Ejecutar el instalador

```bash
sudo install -o root -g root -m 0755 \
  /home/codex-lab/staging/soc-operations-install \
  /usr/local/sbin/soc-operations-install

sha256sum /usr/local/sbin/soc-operations-install
```

Hash esperado:

```text
7be46ce005bbf45db86eeb9d78da44f2b0fbe46f92284d095e2e6355035aedd4
```

Después:

```bash
sudo /usr/local/sbin/soc-operations-install preflight

sudo /usr/local/sbin/soc-operations-install apply \
  --email INGENIERO@EMPRESA.COM \
  --display-name "Primer ingeniero SOC"
```

`apply` debe terminar en `phase=waiting_for_openbao_custody`.

El instalador no modifica el firewall. Antes de `resume`, aplique manualmente las reglas aprobadas,
incluida la comunicación del bridge Docker hacia `172.19.0.1:8443/TCP`.

## 7. OpenBao y primer usuario

```bash
sudo /usr/local/sbin/soc-operations-install openbao-init
sudo /usr/local/sbin/soc-operations-install status
sudo /usr/local/sbin/soc-operations-install resume
```

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
