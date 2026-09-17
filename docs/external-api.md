# API externa de solo lectura compatible con IRIS

Esta superficie permite que Kriptome App consuma clientes/tenants y casos con las rutas y el
envoltorio de respuesta usados por IRIS. Es una fachada de **solo lectura**: no expone altas,
ediciones, transiciones, evidencias ni acciones de administración.

La fachada se ejecuta como proceso separado mediante `soc-external-api`. Su listener predeterminado
es `127.0.0.1:8091`; la API interna del Dashboard continúa en `127.0.0.1:8080`. Las rutas `/manage`
y `/api/v2/cases` no están registradas en el proceso interno, por lo que no pueden consultarse por
el puerto `8080`.

## Arquitectura y puertos

El consumidor siempre utiliza HTTPS estándar por `443`. El puerto alterno existe únicamente en el
salto privado entre HAProxy y WA001; no se publica en DNS ni se entrega a los consumidores:

```text
Cliente -> Cloudflare:443 -> HAProxy:443 -> WA001 Nginx:9443 -> 127.0.0.1:8091
```

Wazuh Dashboard conserva `10.0.0.10:443`. Nginx añade un listener independiente en
`10.0.0.10:9443`, restringido a `192.168.4.50`, y reenvía únicamente las rutas de lectura hacia
el contenedor en loopback.

| Puerto en WA001 | Exposición | Uso |
|---|---|---|
| `443/tcp` | HAProxy y VPN según la política del Dashboard | Wazuh Dashboard |
| `9443/tcp` | Solo `192.168.4.50/32` | Origen TLS privado de la API externa |
| `8091/tcp` | Solo `127.0.0.1` | Listener interno de `soc-external-api` |
| `8080/tcp` | Solo `127.0.0.1` | API interna del plugin/Dashboard |
| `8443/tcp` | Redes internas autorizadas | Agente privilegiado con mTLS |
| `55000/tcp` | No abrir para consumidores | API nativa de Wazuh |
| `9200/9300` | No abrir para consumidores | OpenSearch y transporte del clúster |

La regla administrada en WA001 es:

```bash
sudo ufw allow in on ens19 from 192.168.4.50/32 to 10.0.0.10 port 9443 proto tcp \
  comment 'SOC Operations external API from HAProxy'
```

No publicar `8091` mediante Docker en una interfaz externa. Además de perder TLS, los puertos
publicados por Docker pueden eludir las cadenas normales de UFW. Comprobar:

```bash
sudo ss -lntH | grep -E ':(8091|9443) '
sudo ufw status numbered
```

El resultado esperado es `127.0.0.1:8091` y `10.0.0.10:9443`.

## Activación segura en WA001

El instalador de SOC Operations no crea ni modifica reglas de firewall. Los siguientes comandos son
una sugerencia operativa y deben aplicarse manualmente después de validar interfaz, origen y política
de red aprobada.

El filtrado de clientes se realiza en Cloudflare y HAProxy. La aplicación conserva la IP real para
auditoría, pero no repite la allowlist de consumidores. En
`/etc/soc-operations-lab/runtime.env`:

```env
SOC_EXTERNAL_API_ENABLED=true
SOC_EXTERNAL_API_PUBLISH_ADDRESS=127.0.0.1
SOC_EXTERNAL_API_CLIENT_ALLOWLIST_ENABLED=false
SOC_EXTERNAL_API_ALLOWED_NETWORKS=
SOC_EXTERNAL_API_TRUSTED_PROXY_NETWORKS=172.21.0.1/32
SOC_EXTERNAL_API_KEY_PEPPER_FILE=/run/soc-operations/external-api-pepper
```

`172.21.0.1/32` es el peer Docker esperado cuando Nginx en el host reenvía a la publicación
loopback. Nginx solo acepta al HAProxy administrado y conserva el `X-Forwarded-For` que HAProxy
ya limpió y reconstruyó desde `CF-Connecting-IP`.

Después de editar la configuración:

```bash
sudo docker compose \
  --project-name soc-operations-wa001 \
  --env-file /etc/soc-operations-lab/runtime.env \
  --file /opt/soc-operations-lab/docker-compose.yml \
  up --detach --no-deps --force-recreate external-api

curl --fail http://127.0.0.1:8091/health/live
sudo nginx -t
sudo systemctl reload nginx
```

Una solicitud externa sin clave debe responder `401`; una clave sin alcance o sin acceso al tenant
debe responder `403`. El listener `9443` debe rechazar cualquier origen distinto de HAProxy.

## Controles obligatorios

La publicación aplica controles acumulativos:

1. Cloudflare proxied y WAF/rate limiting para el hostname de la API.
2. HAProxy en modo `cloudflare`, validando la red de origen antes de aceptar `CF-Connecting-IP`.
3. UFW y Nginx permiten `9443` únicamente desde `192.168.4.50/32`.
4. Nginx publica solo métodos `GET` bajo `/manage/` y `/api/v2/cases`.
5. La API exige una clave con alcances y tenants explícitos.

La allowlist interna de clientes puede reactivarse estableciendo
`SOC_EXTERNAL_API_CLIENT_ALLOWLIST_ENABLED=true` y cargando CIDR mínimos en
`SOC_EXTERNAL_API_ALLOWED_NETWORKS`. No se admite una red universal. El archivo pepper debe
contener al menos 32 bytes aleatorios, ser legible solo por el proceso y estar respaldado fuera
del host:

```bash
install -d -m 0700 /etc/soc-operations/secrets
openssl rand -base64 48 > /etc/soc-operations/secrets/external-api-pepper
chmod 0600 /etc/soc-operations/secrets/external-api-pepper
```

No se debe copiar el pepper a Git, imágenes OCI, variables del navegador ni registros.

## Alta en el HAProxy administrado

La configuración de `D:\GPT\Haproxy\Estructura` ya valida `CF-Connecting-IP`, elimina valores
aportados por el cliente y reconstruye `X-Forwarded-For` y `X-Real-IP`. Para un hostname como
`api-soc.kriptome.com`, agregar:

```text
# maps/routing/http-host-backend.map
api-soc.kriptome.com backend_soc_operations_api

# maps/routing/https-host-backend.map
api-soc.kriptome.com backend_soc_operations_api

# maps/policy/host-access-mode.map
api-soc.kriptome.com cloudflare
```

No agregar el hostname a `admin-hosts.lst`: la API es pública a través de Cloudflare y se autentica
con clave. En `conf.d/31-backend-applications.cfg`:

```haproxy
backend backend_soc_operations_api
    mode http
    option httpchk GET /health/live
    http-check expect status 200
    server soc-operations-api 10.0.0.10:9443 ssl verify required \
        ca-file /etc/haproxy/ca/soc-operations-wa001-service-ca.pem \
        sni str(soc-deploy-agent-wa001) check check-sni soc-deploy-agent-wa001
```

La CA se obtiene de WA001 en `/etc/soc-deploy-agent/tls/service-ca.crt`. Validar HAProxy antes de
recargar. La interfaz administrativa `/api/v1/admin/external-api-keys` no se publica por este
hostname.

## Creación y revocación de claves

Un administrador o Ingeniería crea la clave desde la API interna autenticada del Dashboard:

```http
POST /api/v1/admin/external-api-keys
Content-Type: application/json

{
  "name": "kriptome-app-produccion",
  "tenant_ids": ["soc-tenant-beta"],
  "scopes": ["customers:read", "cases:read", "metrics:read"],
  "expires_at": "2027-09-16T00:00:00Z"
}
```

`api_key` se devuelve una sola vez. En la base únicamente se conserva una huella HMAC-SHA256 con
pepper. La revocación es inmediata:

```http
POST /api/v1/admin/external-api-keys/{credential_id}/revoke
```

Cada uso registra `last_used_at` y `last_used_ip`; creación y revocación generan auditoría.

## Autenticación del consumidor

Se aceptan las dos formas para facilitar consumidores IRIS existentes:

```http
X-IRIS-AUTH: soc_live_...
```

o:

```http
Authorization: Bearer soc_live_...
```

Una clave nunca puede consultar un tenant que no figure en `tenant_ids`, aunque conozca su ID,
UUID de caso o ID numérico compatible con IRIS.

Ejemplos de consumo:

```bash
curl --fail-with-body \
  --header "X-IRIS-AUTH: ${IRIS_API_KEY}" \
  https://soc-api.example.com/manage/customers/list

curl --fail-with-body --get \
  --header "Authorization: Bearer ${IRIS_API_KEY}" \
  --data-urlencode "case_customer_id=12" \
  --data-urlencode "case_state_id=3" \
  --data-urlencode "order_by=case_open_date" \
  --data-urlencode "sort_dir=desc" \
  --data-urlencode "page=1" \
  --data-urlencode "per_page=25" \
  https://soc-api.example.com/manage/cases/filter
```

Flujo mínimo para probar desde una IP autorizada:

```bash
export SOC_API_BASE='https://soc-api.example.com'
export IRIS_API_KEY='soc_live_REEMPLAZAR'

curl --fail-with-body \
  --header "X-IRIS-AUTH: ${IRIS_API_KEY}" \
  "${SOC_API_BASE}/manage/customers/list"

curl --fail-with-body --get \
  --header "X-IRIS-AUTH: ${IRIS_API_KEY}" \
  --data-urlencode 'page=1' \
  --data-urlencode 'per_page=25' \
  "${SOC_API_BASE}/api/v2/cases"
```

No usar `--insecure` en producción. Un resultado `401` indica clave ausente o inválida; `403`
indica alcance insuficiente, tenant no autorizado o rechazo de una allowlist interna habilitada;
`200` confirma acceso.

La conexión pública termina TLS en HAProxy. El proxy vuelve a cifrar hacia `10.0.0.10:9443` y
Nginx reenvía las rutas autorizadas a `127.0.0.1:8091`. No se publican directamente `8080` ni
`8091`.

## Endpoints publicados

| Endpoint | Alcance | Contenido |
|---|---|---|
| `GET /manage/customers/list` | `customers:read` | tenants autorizados |
| `GET /manage/customers/{id}` | `customers:read` | detalle, patrón de índices y retención |
| `GET /manage/customers/{id}/sla` | `customers:read` | SLA por severidad |
| `GET /manage/customers/{id}/analysts` | `customers:read` | analistas, junior y managers activos |
| `GET /manage/customers/{id}/endpoints` | `customers:read` | agentes/endpoints paginados |
| `GET /manage/customers/{id}/cases` | `cases:read` | casos y métricas del tenant |
| `GET /manage/cases/filter` | `cases:read` | filtro paginado compatible con IRIS |
| `GET /manage/cases/{id}` | `cases:read` | detalle por ID IRIS o UUID SOC |
| `GET /manage/cases/{id}/timeline` | `cases:read` | historial auditable paginado |
| `GET /api/v2/cases` | `cases:read` | alias moderno paginado |
| `GET /api/v2/cases/{id}` | `cases:read` | alias moderno de detalle |

Las listas admiten como máximo 100 elementos por página. `/manage/cases/filter` conserva los
parámetros principales de IRIS (`page`, `per_page`, `case_ids`, `case_customer_id`, nombre,
descripción, owner, severidad, estado, fechas, orden y `search[value]`). Cuando la clave posee
`metrics:read`, la respuesta incorpora métricas agregadas, distribución por origen/severidad y
relojes SLA vencidos.

Los IDs numéricos de cliente y caso se almacenan en tablas de mapeo estables; el UUID original y
`tenant_id` también se devuelven. La migración crea esos mapeos para datos existentes.

## Puesta en producción

1. Aplicar la migración Alembic `af2c8e74d910`.
2. Crear y montar el pepper con permisos `0600`.
3. Instalar la CA interna de WA001 en HAProxy y configurar el backend TLS `9443`.
4. Publicar el hostname en modo `cloudflare` y aplicar primero UFW/Nginx.
5. Activar `SOC_EXTERNAL_API_ENABLED=true` y reiniciar la API.
6. Crear una clave por consumidor, con vencimiento y el mínimo número de tenants/alcances.
7. Validar por Cloudflare y comprobar que una conexión directa a `9443` desde otro origen falla.
8. Monitorizar usos, rotar claves y probar revocación.

Si se activa la allowlist interna de clientes, no se debe habilitar una red amplia (`0.0.0.0/0` o
`::/0`). Tampoco se debe confiar en todo el segmento de contenedores: solo en el peer exacto que
corresponda al Nginx administrado y que se haya verificado en WA001.
