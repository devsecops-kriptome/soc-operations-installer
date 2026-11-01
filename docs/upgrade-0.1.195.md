# Actualización a SOC Operations 0.1.195 — AIO y distribuido

1. Registrar hostname, versión, phase=complete, topología e identidad persistidas,
   componentes Wazuh, esquema, servicios y espacio. Usar los datos de ese destino.
2. Crear un respaldo NUEVO de PostgreSQL, OpenBao, objetos/versiones, reportes,
   snapshots publicados y configuración. Verificar contenido e integridad, cifrar
   y comprobar descifrado. Custodiar auto-unseal por separado; preservar su original.
   Conservar también la recuperación anterior y el baseline de cuentas y conteos.
3. Verificar SHA256SUMS del paquete cifrado, descifrar con la identidad autorizada
   en un directorio privado nuevo y verificar el hash del TAR claro. No compartir claves.
4. Inspeccionar rutas, duplicados, tipos y ausencia de enlaces antes de extraer el TAR.
   Verificar SHA256SUMS interno completo y usar staging privado release-0.1.195.
5. Ejecutar preflight con la identidad existente. Antes de upgrade comprobar respaldo,
   capacidad y ventana de mantenimiento. No usar apply/resume para sustituir upgrade.
   En distribuido el agente debe quedar en 0.1.138 antes del runtime por el flujo
   previsto del instalador. Si el agente es local, el instalador lo reconcilia.
6. Usar el nuevo soc-operations-install con upgrade --staging-root RUTA_VERIFICADA,
   conservando service-address, external-proxy-cidr y topología del propio destino.
   No trasladar rutas, IP ni baseline de otro lab o servidor.
7. Confirmar phase=complete, instalador 0.1.195, runtime/agente 0.1.138,
   plugin 0.1.117 y esquema f97dc8e12543. Comparar baseline, cuenta protegida,
   fingerprint auto-unseal, readiness, TLS/timer, versiones y reinicios.
8. Probar permisos y aislamiento entre tenants, API externa con sus alcances,
   métricas sobre casos automáticos, En progreso, relaciones y copia de cierre.
   Revisar políticas personalizadas existentes; no reescribir históricos para obtener SLA.
9. Validar un escalamiento controlado con destinatario y copia autorizados, incluidos
   contactos externos cuando corresponda. Contrastar actividad, estado y Message-ID
   con el SMTP/buzón. Una entrega incierta requiere revisión antes de reenviar.
10. Validar un reporte real, sus adjuntos y el navegador. Conservar registros,
    staging anterior y respaldos hasta completar la aceptación del destino.

El paquete no incluye secretos de producción ni modifica por sí solo servidores.
Las instrucciones específicas del destino se preparan con su estado y respaldo actuales.


## Verificación por etapas

Cada destino necesita sus propios tamaños, baseline, rutas y respaldo. La guía no autoriza borrar
volúmenes ni reutilizar una copia anterior como si fuera un respaldo actual.
