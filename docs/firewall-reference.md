# Referencia manual de firewall

El instalador no instala, habilita ni modifica UFW, nftables o iptables. Esta matriz es una
sugerencia para el perfil WA001 y debe adaptarse a la política aprobada.

| Destino | Origen recomendado | Finalidad |
| --- | --- | --- |
| `PUERTO_SSH/TCP` | Red administrativa | Administración |
| `10.0.0.10:443/TCP` | `192.168.4.50/32`, y VPN si aplica | Dashboard |
| `10.0.0.10:9443/TCP` | Solo `192.168.4.50/32` | API externa desde HAProxy |
| `10.0.0.10:1514/TCP` | LAN de endpoints y VPN | Eventos Wazuh |
| `10.0.0.10:1515/TCP` | LAN de endpoints y VPN | Enrolamiento Wazuh |
| `172.19.0.1:8443/TCP` | Bridge Docker `172.19.0.0/16` | Agente mTLS interno |

No publique `8080`, `8091`, `8200`, `9000`, `9200`, `5432` ni `55000`.

El release `v0.1.100` fija la red `frontend` a `172.19.0.0/16` con gateway `172.19.0.1`.
Después de `apply`, obtenga y valide los valores efectivos antes de crear la regla:

```bash
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
```

Si cualquiera de las tres validaciones falla, no adapte la regla al valor encontrado: deténgase
y revise solapamientos o una recreación incorrecta de la red Docker.

Antes de habilitar UFW, autorice el puerto SSH correcto y valide otra sesión para evitar perder el
acceso. Registre las reglas aplicadas como un cambio de red independiente del instalador.
