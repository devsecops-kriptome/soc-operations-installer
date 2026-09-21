# Respaldo y recuperación AIO o distribuida

El release `0.1.148` ejecuta el flujo de continuidad desde el único Dashboard, ya sea AIO o
distribuido. Su objetivo es reconstruir SOC Operations sin volver a crear manualmente tenants,
usuarios, casos, incidentes, SLA, playbooks, reportes y configuración operativa.

## Qué protege

- PostgreSQL mediante un `pg_dump` consistente;
- reportes DOCX/CSV;
- snapshot Raft de OpenBao;
- exportación cifrada de usuarios, hashes, roles y mappings de seguridad OpenSearch;
- configuración técnica, certificados y tokens de workload;
- snapshot OpenSearch externo de alertas, archivos, vulnerabilidades, índices SOC y objetos de
  Dashboard;
- réplica opcional de evidencias al almacenamiento S3.

El bundle se cifra localmente antes de enviarse a S3. El bucket debe ser externo al Dashboard, tener
cifrado, versionado y, para producción, Object Lock.

## Qué nunca incluye

- `/etc/soc-operations-lab/openbao/auto-unseal.key`;
- el token raíz de OpenBao;
- las cinco recovery shares;
- la clave privada usada para descifrar el backup.

Estos elementos se conservan por canales separados. El snapshot Raft no puede restaurarse sin la
clave de auto-unseal original, y la administración de OpenBao requiere el token raíz o tres de las
cinco recovery shares.

## Configuración inicial

El release extraído contiene:

```text
soc-aio-continuity
soc-aio-continuity.service
soc-aio-continuity.timer
continuity.env.example
aio-disaster-recovery.md
```

La guía detallada `aio-disaster-recovery.md` forma parte del paquete cifrado. Antes de habilitar el
timer, prepare un bucket S3 externo, un certificado público de cifrado y credenciales limitadas.
Después configure una vez el token de snapshot de OpenBao:

```bash
sudo /usr/local/sbin/soc-aio-continuity configure-openbao
```

El token raíz se introduce mediante un prompt oculto y no se guarda. Luego valide y genere el
primer checkpoint:

```bash
sudo /usr/local/sbin/soc-aio-continuity preflight
sudo /usr/local/sbin/soc-aio-continuity backup initial-production
sudo /usr/local/sbin/soc-aio-continuity list
```

Solo después de verificar el checkpoint habilite el respaldo periódico:

```bash
sudo systemctl enable --now soc-aio-continuity.timer
systemctl list-timers soc-aio-continuity.timer
```

## Recuperación

La recuperación se prueba en una red aislada y sigue este orden:

1. instalar la misma topología Wazuh `4.14.7-1` y SOC Operations en el Dashboard nuevo;
2. configurar acceso temporal de lectura al repositorio S3/OpenSearch;
3. recuperar por el canal independiente la `auto-unseal.key` original;
4. montar temporalmente la clave privada de descifrado;
5. ejecutar `restore-stage` y revisar manifiesto, hashes y conteos;
6. ejecutar `restore-application` con confirmación explícita;
7. restaurar el snapshot OpenSearch sin los índices de seguridad y con
   `include_global_state=false`;
8. reconciliar índices, DLS, roles tenant, grupos y espacios Dashboard;
9. deshabilitar el modo restore y rotar las credenciales temporales.

Un backup no se considera válido hasta completar una restauración real. Como mínimo deben
compararse tenants, usuarios, casos, auditoría, reportes y evidencias, y probarse dos usuarios de
tenants distintos sin acceso cruzado. Los objetivos iniciales son RPO de 15 minutos para
PostgreSQL, una hora para índices activos y RTO de cuatro horas.

## Alcance de esta versión

Este flujo admite un único Dashboard y no elimina ese dominio único de fallo. Producción crítica
debe usar almacenamiento externo y evaluar PostgreSQL administrado y OpenBao HA con auto-unseal
basado en KMS/HSM/Transit. No promueva `0.1.148` a producción hasta completar la instalación limpia y el
simulacro de restauración.
