# Aceptación de laboratorio

No promover a producción mientras algún control obligatorio permanezca sin evidencia.

## Identidad y aislamiento

- [ ] Instalar desde cero con PostgreSQL 17 y ejecutar todas las migraciones.
- [ ] Verificar Global y cuarentena, sus cuatro políticas ISM de 30 días y ausencia de acceso tenant.
- [ ] Crear dos tenants sintéticos con prefijos distintos; confirmar los cuatro perfiles de cada uno.
- [ ] Con cada rol tenant, consultar el data view Wazuh `wazuh-alerts-*` y confirmar mediante DLS
  que solo devuelve `tenant.id` propio; validar `wazuh-monitoring-*` solo para el grupo principal.
- [ ] Negar a roles tenant `wazuh-statistics-*`, `wazuh-states-*` y el catálogo global de índices.
- [ ] Probar cada rol, roles acumulados y consultas/IDs cruzados. Búsqueda, lectura y escritura ajena
      deben ser denegadas aun quitando filtros del Dashboard.
- [ ] Activar una identidad, reusar el enlace, vencerlo a 48 horas, reemitirlo e invalidar el anterior.
- [ ] Confirmar que correo, logs, auditoría y PostgreSQL no contienen la contraseña.
- [ ] Suspender un tenant y una membresía sin eliminación destructiva.

## Operación SOC

- [ ] Crear equipo multi-tenant, turnos, un `R`, backups y vacaciones superpuestas.
- [ ] Crear un caso automático, comprobar asignación al `R` y ACK.
- [ ] Dejar un caso sin ACK: transferencia a los 10 minutos y escalamiento final al manager.
- [ ] Interrumpir SMTP y Slack; comprobar reintentos idempotentes, límite y auditoría.
- [ ] Validar recordatorios de vacaciones, varias anticipaciones y rechazo de CC no autorizada.
- [ ] Correlacionar varias alertas por las claves permitidas y ventana; conservar `_index`, `_id` y hash.
- [ ] Ejecutar SLA 24x7/cobertura, pausa justificada, reanudación y reapertura.
- [ ] Instanciar un plan de respuesta y comprobar que una versión posterior no cambia el caso existente.
- [ ] Leer hallazgos propios y negar todo `agent.id`, documento y decisión de otro tenant.

## PKI tenant y enrolamiento masivo

- [ ] Configurar dos emisoras/perfiles tenant y comprobar que el manager acepta únicamente sus
      cadenas públicas autorizadas.
- [ ] Enrolar dos endpoints del mismo tenant; confirmar certificados con seriales y claves públicas
      diferentes y ausencia de claves privadas en API, base de datos, navegador, logs y artefactos.
- [ ] Rechazar una CSR de tenant A presentada con una campaña, grupo o perfil de tenant B.
- [ ] Probar autorización válida, alterada, vencida, reutilizada y por encima de la cuota sin revelar
      si el dispositivo existe.
- [ ] Validar el certificado del manager desde el endpoint y rechazar nombre, cadena o vigencia
      inválidos.
- [ ] Confirmar enrolamiento por `1515`, emisión de clave individual Wazuh y comunicación posterior
      por `1514`; documentar que son credenciales y etapas diferentes.
- [ ] Probar NAT, DHCP y balanceador antes de decidir `ssl_verify_host`.
- [ ] Dar de baja un agente: revocar en PKI, bloquear nuevas altas y deshabilitar/eliminar su
      identidad Wazuh; verificar que no vuelve a conectar.
- [ ] Rotar la emisora de un tenant mediante bundle atómico y rollback sin afectar al segundo.
- [ ] Ejecutar campañas sintéticas de 10 y 100 endpoints, con pausa, reanudación, backoff e
      idempotencia; no usar el AIO WA001 como prueba de capacidad para miles.

## Decoder Studio

- [ ] Detectar primero un decoder existente mediante `wazuh-logtest`.
- [ ] Probar XML/prompt injection, MITRE inválido, ID duplicado y regex con backtracking costoso.
- [ ] Ejecutar positivos, negativos, regresión y fuzz en manager desechable sin red.
- [ ] Caída IA local: cerrar o usar fallback exclusivamente con contenido redactado.
- [ ] Dos aprobadores independientes; verificar artefacto y manifiesto ECDSA.
- [ ] Desplegar en canario al maestro, comprobar sincronización, health check y rollback automático.

## Continuidad y contratos

- [ ] Restaurar PostgreSQL a un punto dentro de RPO 15 minutos.
- [ ] Restaurar objetos S3 y snapshots OpenSearch sin `.opendistro_security`.
- [ ] Medir recuperación completa dentro de RTO 4 horas y conservar evidencias.
- [ ] Ejecutar dos migraciones de ensayo IRIS con conteos, hashes y reconciliación.
- [ ] Comparar `/api/v2` byte/semánticamente contra fixtures de cada consumidor real.
- [ ] Validar el contrato de métricas de Kriptome App una vez entregado.
- [ ] Compilar e instalar el plugin contra OSD 2.19.5 y repetir tras cada actualización Wazuh.
