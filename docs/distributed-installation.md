# Instalación distribuida de SOC Operations 0.1.144

## Topología admitida

- exactamente un Wazuh Dashboard `4.14.7-1` con OpenSearch Dashboards `2.19.5`;
- uno o varios Wazuh Manager `4.14.7-1` pertenecientes al mismo clúster;
- uno o varios Wazuh Indexer `4.14.7-1` pertenecientes al mismo clúster.

SOC Operations se instala únicamente en el Dashboard. El manager master recibe solo el agente
privilegiado mTLS. No se admiten varios Dashboard ni varios clústeres Wazuh independientes en una
misma instancia.

La API externa de solo lectura `9443`, PostgreSQL, OpenBao y la continuidad integrada permanecen
en el Dashboard. El Manager master ejecuta únicamente el agente privilegiado mTLS.

## Preparación

Descargue, verifique, descifre y extraiga el release siguiendo la sección 3 de la
[guía AIO](installation.md). El resultado debe ser `/root/soc-installer/release-0.1.144` con 27
archivos y `SHA256SUMS` válido.

Desde el Dashboard deben ser accesibles:

- `9200/tcp` del endpoint estable o balanceador Indexer;
- `55000/tcp` del endpoint API del clúster Manager;
- `8443/tcp` del manager master.
- entrada `9443/tcp` al Dashboard únicamente desde HAProxy/reverse proxy.

Instale en el Dashboard el certificado administrativo/clave/CA de Indexer y la CA de la API
Wazuh. Configure `wazuh.yml` con un único endpoint lógico HTTPS/55000, usuario `wazuh-wui` y
`run_as: true`. Los certificados remotos deben contener el DNS usado.

Copie `topology.example.json` a `/root/soc-topology.json` y ajuste:

- `deployment_id`;
- cantidades exactas de managers e indexers;
- endpoint Indexer estable;
- endpoint del agente en el manager master;
- rutas root-only de certificados.

Los archivos `deployment_*` todavía no existen: se generarán en la etapa del manager.

## Etapa 1: Dashboard

```bash
cd /root/soc-installer/release-0.1.144
install -o root -g root -m 0755 ./soc-operations-install \
  /usr/local/sbin/soc-operations-install

sudo /usr/local/sbin/soc-operations-install preflight \
  --topology-file /root/soc-topology.json \
  --staging-root "$PWD"

sudo /usr/local/sbin/soc-operations-install apply \
  --topology-file /root/soc-topology.json \
  --email INGENIERO@EMPRESA.COM \
  --display-name "Primer ingeniero SOC" \
  --public-url https://dashboard.example.com \
  --external-proxy-cidr IP_HAPROXY/32 \
  --staging-root "$PWD"

sudo /usr/local/sbin/soc-operations-install openbao-init
sudo /usr/local/sbin/soc-operations-install resume
```

Custodie las recovery shares, el token root y `auto-unseal.key` como explica la guía AIO. El
primer `resume` distribuido debe quedar en `waiting_for_manager_agent`. Para entonces el Dashboard
habrá generado estas claves públicas:

```text
/etc/soc-deploy-agent/release-signing.pem
/etc/soc-deploy-agent/provisioning-signing.pem
```

## Etapa 2: manager master

Copie al manager el release, las dos claves públicas, las credenciales administrativas de
Indexer, la CA de API Wazuh y una copia `0600` root-only de `wazuh.yml`.

```bash
cd /root/soc-installer/release-0.1.144
install -o root -g root -m 0755 ./soc-lab-tenant-provisioner \
  /usr/local/sbin/soc-lab-tenant-provisioner
install -d -o root -g root -m 0755 /etc/soc-deploy-agent
install -o root -g root -m 0444 release-signing.pem \
  /etc/soc-deploy-agent/release-signing.pem
install -o root -g root -m 0444 provisioning-signing.pem \
  /etc/soc-deploy-agent/provisioning-signing.pem

sudo env \
  SOC_WAZUH_TOPOLOGY=distributed \
  SOC_DEPLOYMENT_ID=wazuh-prod \
  SOC_STAGING_ROOT="$PWD" \
  SOC_AIO_SERVICE_ADDRESS=IP_LOCAL_MANAGER_MASTER \
  SOC_EXTERNAL_API_PROXY_CIDR=127.0.0.1/32 \
  SOC_DEPLOYMENT_AGENT_URL=https://manager-master.example.com:8443 \
  SOC_INDEXER_URL=https://indexer-lb.example.com:9200 \
  SOC_INDEXER_ADMIN_CERT=/etc/soc-deploy-agent/indexer-admin.pem \
  SOC_INDEXER_ADMIN_KEY=/etc/soc-deploy-agent/indexer-admin-key.pem \
  SOC_INDEXER_CA_BUNDLE=/etc/soc-deploy-agent/indexer-root-ca.pem \
  SOC_WAZUH_API_CONFIG=/etc/soc-deploy-agent/wazuh.yml \
  SOC_WAZUH_API_CA_BUNDLE=/etc/soc-deploy-agent/wazuh-api-ca.pem \
  /usr/local/sbin/soc-lab-tenant-provisioner install
```

Devuelva al Dashboard, mediante un canal protegido, el contenido de
`/etc/soc-operations-lab/deploy-tls/`. Instale `client.crt`, `client.key` y `service-ca.crt` en las
rutas `deployment_*` declaradas en el JSON. La clave debe conservarse `root:root 0600` durante el
traslado.

## Etapa 3: completar en el Dashboard

```bash
sudo /usr/local/sbin/soc-operations-install resume
sudo /usr/local/sbin/soc-operations-install status
```

La salida debe incluir `installer_version=0.1.144`, `topology=distributed`, el `deployment_id`
esperado, `phase=complete`, `external_api_gateway=200` y las sondas HTTP `200` de la API.

## API externa en el Dashboard

El instalador crea un gateway Nginx dedicado en `IP_DASHBOARD:9443`; el contenedor permanece en
`127.0.0.1:8091`. La CA pública para HAProxy queda en
`/etc/soc-operations-lab/external-api-tls/ca.crt` y el nombre verificable es
`soc-external-api-DEPLOYMENT_ID`. Las claves privadas no deben salir del Dashboard. La activación
funcional y creación de credenciales se describen en [API externa](external-api.md).

## Continuidad

El comando `soc-aio-continuity` conserva su nombre por compatibilidad, pero en `0.1.144` lee
`topology.env`, valida el número de nodos y solicita el snapshot al endpoint Indexer remoto. El
repositorio de snapshots debe existir en todos los Indexer y apuntar a S3 durable. Durante una
recuperación distribuida, restaure primero Wazuh/Indexer y su snapshot; luego restaure SOC
Operations. La seguridad base Wazuh se conserva y los roles, tenants y usuarios SOC se regeneran
desde la base restaurada.

Antes de producción pruebe pérdida de un nodo, conmutación del manager master, aislamiento entre
dos tenants, casos, reportes, vulnerabilidades y restauración separada de SOC Operations, Manager
e Indexer. El release fue validado estáticamente y mediante pruebas automatizadas; la aceptación
en una infraestructura distribuida real sigue siendo obligatoria.
