# Actualización a SOC Operations 0.1.196 — AIO y distribuido

1. Registrar hostname, instalador, phase=complete, topología, deployment_id,
   direcciones persistidas, versiones Wazuh, esquema, servicios y espacio del destino.
2. Crear un respaldo NUEVO de PostgreSQL, OpenBao, objetos/versiones, reportes,
   snapshots publicados y configuración. Verificar contenido, integridad y descifrado.
   Custodiar auto-unseal por separado y conservar su original, recuperación anterior
   y baseline de cuentas, conteos, reglas habilitadas y filtros de automatización.
3. Verificar SHA256SUMS del paquete cifrado y descifrar en un directorio privado nuevo
   con la identidad autorizada. Verificar también el hash del TAR claro; no compartir claves.
4. Inspeccionar rutas, tipos, duplicados y ausencia de enlaces antes de extraer.
   Verificar todo SHA256SUMS interno y usar staging privado release-0.1.196.
5. Revisar el alcance de las reglas personalizadas activas. Los filtros positivos
   delimitan un ámbito con AND, y los ámbitos se combinan con OR. Dentro del ámbito
   del tenant la regla global no elude exclusiones; otra regla del tenant puede aceptar
   la alerta. Fuera de esos ámbitos se evalúan las globales aplicables.
   Una regla con solo != o exclusiones de grupos puede abarcar muchas alertas:
   acotarla con tecnología, rule.id u otro selector positivo cuando corresponda.
6. Ejecutar preflight con la identidad y direcciones existentes. Verificar respaldo,
   capacidad y ventana de mantenimiento antes de upgrade. No sustituir upgrade por
   apply/resume. En distribuido el agente debe quedar en 0.1.139 antes del runtime
   por el flujo previsto; el instalador reconcilia el agente cuando es local.
7. Ejecutar el nuevo soc-operations-install con upgrade --staging-root RUTA_VERIFICADA,
   conservando service-address, external-proxy-cidr y topología de ese destino.
   No copiar IP, rutas privadas o baseline de otro servidor.
8. Confirmar phase=complete, instalador 0.1.196, runtime/agente 0.1.139,
   plugin 0.1.118 y esquema f97dc8e12543. Comparar cuenta protegida y conteos,
   fingerprint auto-unseal, readiness, TLS/timer, versiones y reinicios.
   Desde 0.1.195 no hay migraciones nuevas; desde versiones anteriores se aplican
   las pendientes del paquete, sin reconstruir hitos ni reclasificar casos históricos.
9. Validar con alertas controladas del tenant: coincidencia personalizada, exclusión,
   regla alternativa y alerta de otra tecnología elegible para la global. Comprobar
   categoría fija/heredada, severidad, MITRE y playbook de la primera alerta.
   Si mitre.id es clave, el mismo conjunto en otro orden debe vincularse al caso
   dentro de la ventana; técnicas, claves o tenants distintos deben conservar separación.
10. Verificar permisos y aislamiento, API externa autenticada, métricas, navegador,
    un reporte real y un correo controlado con destinatarios/copias autorizados.
    La aceptación SMTP no prueba llegada a bandeja. No reenviar entregas inciertas
    sin revisar su referencia. Conservar logs privados, staging y respaldos hasta aceptar.

La identidad privada age se obtiene del gestor autorizado y no se publica.
El paquete no modifica servidores hasta ejecutar expresamente el instalador.
