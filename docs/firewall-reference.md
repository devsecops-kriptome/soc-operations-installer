# Referencia manual de firewall

El instalador no instala, habilita ni modifica UFW, nftables o iptables. Esta matriz debe
adaptarse a las redes aprobadas de cada servidor; no depende del hostname ni del identificador del
cluster.

| Destino | Origen recomendado | Finalidad |
| --- | --- | --- |
| `PUERTO_SSH/TCP` | Red administrativa | Administración |
| `IP_AIO:443/TCP` | Reverse proxy y VPN autorizada | Wazuh Dashboard |
| `IP_AIO:9443/TCP` | Solo reverse proxy autorizado | API externa SOC |
| `IP_AIO:1514/TCP` | Proxy de agentes o redes de endpoints | Eventos Wazuh |
| `IP_AIO:1515/TCP` | Proxy de agentes o redes de endpoints | Enrolamiento Wazuh |
| `172.19.0.1:8443/TCP` | Bridge Docker `172.19.0.0/16` | Agente mTLS interno |

No publique `8080`, `8091`, `8200`, `9000`, `9200`, `5432` ni `55000`.

## Perfil distribuido

En distribuido, mantenga el mismo acceso externo a `443` del Dashboard y agregue únicamente flujos
internos explícitos:

| Origen | Destino | Puerto | Finalidad |
| --- | --- | --- | --- |
| Dashboard SOC | Endpoint/Balanceador Indexer | `9200/TCP` | Seguridad, identidades y búsquedas |
| Dashboard SOC | Endpoint API Manager | `55000/TCP` | RBAC Wazuh y validación del clúster |
| Dashboard SOC | Manager master | `8443/TCP` | Agente privilegiado mTLS |
| Manager master | Endpoint/Balanceador Indexer | `9200/TCP` | Inventario, DLS y gateway de vulnerabilidades |

No aplique la regla de bridge hacia `172.19.0.1:8443` en distribuido: los contenedores salen por
ruteo normal al FQDN del manager master. La API externa `9443` todavía no está soportada en este
perfil y debe permanecer cerrada.

## Tráfico externo

Mantenga abierta la sesión SSH actual, autorice primero el puerto SSH real y pruebe una segunda
conexión antes de habilitar UFW. Defina valores reales; siempre que sea posible, use `/32` para
administración y reverse proxy:

```bash
INTERFAZ_SERVICIO=ens19
PUERTO_SSH=22
RED_ADMIN=192.0.2.10/32
IP_PROXY=192.0.2.20
RED_ENDPOINTS=10.20.0.0/16
RED_VPN=10.81.0.0/16
IP_AIO=10.0.0.10

ufw allow in on "$INTERFAZ_SERVICIO" \
  from "$RED_ADMIN" to "$IP_AIO" port "$PUERTO_SSH" proto tcp \
  comment 'SSH administration'
ufw allow in on "$INTERFAZ_SERVICIO" \
  from "$IP_PROXY" to "$IP_AIO" port 443 proto tcp \
  comment 'Wazuh Dashboard from reverse proxy'
ufw allow in on "$INTERFAZ_SERVICIO" \
  from "$IP_PROXY" to "$IP_AIO" port 9443 proto tcp \
  comment 'SOC external API from reverse proxy'
ufw allow in on "$INTERFAZ_SERVICIO" \
  from "$RED_VPN" to "$IP_AIO" port 443 proto tcp \
  comment 'Wazuh Dashboard from VPN'
```

Si 1514/1515 se publican únicamente mediante un proxy de agentes, autorice solo su IP. Si los
endpoints llegan directamente, autorice en su lugar las redes aprobadas. No aplique ambas
modalidades sin necesidad:

```bash
# Modalidad mediante proxy
ufw allow in on "$INTERFAZ_SERVICIO" \
  from "$IP_PROXY" to "$IP_AIO" port 1514 proto tcp \
  comment 'Wazuh events from proxy'
ufw allow in on "$INTERFAZ_SERVICIO" \
  from "$IP_PROXY" to "$IP_AIO" port 1515 proto tcp \
  comment 'Wazuh enrollment from proxy'

# Modalidad directa; úsela en lugar del bloque anterior
for RED_AGENTES in "$RED_ENDPOINTS" "$RED_VPN"; do
  ufw allow in on "$INTERFAZ_SERVICIO" \
    from "$RED_AGENTES" to "$IP_AIO" port 1514 proto tcp \
    comment 'Wazuh direct agent events'
  ufw allow in on "$INTERFAZ_SERVICIO" \
    from "$RED_AGENTES" to "$IP_AIO" port 1515 proto tcp \
    comment 'Wazuh direct agent enrollment'
done
```

## Bridge interno de SOC Operations

El release `v0.1.144` fija la red `frontend` a `172.19.0.0/16` con gateway `172.19.0.1`.
Después de `apply`, obtenga y valide los valores efectivos antes de crear la regla:

```bash
(
set -Eeuo pipefail

SOC_NETWORK=soc-operations-wa001_frontend
SOC_SUBNET=$(docker network inspect "$SOC_NETWORK" \
  --format '{{(index .IPAM.Config 0).Subnet}}')
SOC_GATEWAY=$(docker network inspect "$SOC_NETWORK" \
  --format '{{(index .IPAM.Config 0).Gateway}}')
SOC_BRIDGE=$(docker network inspect "$SOC_NETWORK" \
  --format '{{index .Options "com.docker.network.bridge.name"}}')
if [ -z "$SOC_BRIDGE" ]; then
  SOC_NETWORK_ID=$(docker network inspect "$SOC_NETWORK" --format '{{.Id}}')
  SOC_BRIDGE="br-${SOC_NETWORK_ID:0:12}"
fi

printf 'Subnet: %s\nGateway: %s\nBridge: %s\n' \
  "$SOC_SUBNET" "$SOC_GATEWAY" "$SOC_BRIDGE"

test "$SOC_SUBNET" = "172.19.0.0/16"
test "$SOC_GATEWAY" = "172.19.0.1"
ip -4 address show dev "$SOC_BRIDGE" | grep -Fq '172.19.0.1/16'

ufw allow in on "$SOC_BRIDGE" \
  from "$SOC_SUBNET" to "$SOC_GATEWAY" port 8443 proto tcp \
  comment 'SOC Operations bridge to deploy agent'
ufw status numbered
)
```

Si cualquiera de las validaciones falla, deténgase y revise solapamientos o una recreación
incorrecta de la red Docker. No copie un nombre `br-*` desde otro servidor.

Estos bloques no habilitan UFW. Revise primero `ufw show added`, valide otra sesión SSH y habilite
el firewall únicamente si la política del servidor lo requiere.

## Validar mTLS desde el contenedor API

Cuando `resume` haya instalado el agente de despliegue, el host debe escuchar en `8443`:

```bash
systemctl is-active soc-deploy-agent nginx
ss -lntp | grep ':8443'
```

Pruebe el mismo camino que utiliza la API:

```bash
docker exec -i soc-operations-wa001-api-1 \
  /usr/local/bin/python - <<'PY'
import ssl
import urllib.request

context = ssl.create_default_context(cafile="/run/soc-operations/deploy-ca.crt")
context.load_cert_chain(
    certfile="/run/soc-operations/deploy-client.crt",
    keyfile="/run/soc-operations/deploy-client.key",
)
opener = urllib.request.build_opener(
    urllib.request.ProxyHandler({}),
    urllib.request.HTTPSHandler(context=context),
)
with opener.open(
    "https://soc-deploy-agent-wa001:8443/health/live",
    timeout=10,
) as response:
    print("HTTP", response.status)
    print(response.read().decode())
PY
```

El resultado esperado es `HTTP 200`. Si `resume` se detuvo con `identity_agent: unavailable`,
corrija la ruta de red, confirme esta respuesta y ejecute nuevamente `resume`; no repita `apply`,
`openbao-init` ni rollback.
