# Actualización a SOC Operations 0.1.193

1. Confirmar host, topología persistida, versión, esquema, baseline y espacio libre.
2. Crear y verificar un respaldo NUEVO de PostgreSQL, OpenBao, objetos, reportes y
   configuración, incluyendo los tokens vigentes. Custodiar auto-unseal cifrada por
   separado con otra contraseña. Conservar el instalador y respaldo anteriores.
3. Verificar SHA256SUMS del archivo soc-operations-0.1.193.tar.gz.age, descifrar con
   la identidad autorizada y verificar también el hash del TAR claro. No compartir
   identidades privadas, tokens ni contraseñas.
4. Validar rutas, duplicados, tipos y ausencia de enlaces antes de extraer en un
   staging privado nuevo. Verificar SHA256SUMS interno completo y ejecutar preflight
   con la topología persistida. No sustituirla por valores de otra instalación.
5. Solo con respaldo, baseline y preflight verificados y ventana autorizada, ejecutar
   upgrade --staging-root RUTA_VERIFICADA. No usar apply ni resume para actualizar.
   En distribuido, actualizar antes el agente remoto a 0.1.136 mediante el flujo
   previsto. No copiar helpers individuales ni saltar controles de integridad.
6. Confirmar phase=complete, runtime/API/worker/agente 0.1.136, plugin 0.1.115 y
   esquema a42f71c6e309. Comparar cuenta protegida, conteos, auto-unseal, permisos,
   readiness, certificados, timer y avance del checkpoint.
7. Revisar la identidad del manager 000 y el inventario autenticado del despliegue.
   Si el índice usa un nombre histórico ausente, confirmar su procedencia antes de
   aprobarlo como alias exacto root en /etc/soc-deploy-agent/agent.env. No inferir
   confianza solo por agent.id o agent.name, ni agregar comodines.
8. Probar el reporte real Hostname > paquete con un host y luego varios (máximo 10),
   Excel con una hoja por host, Word, filtros de grupos y rechazo de otro tenant.
   Confirmar los totales completos y las versiones/arquitecturas del inventario.
9. Esperar y comprobar la recolección del resumen bajo la política nueva. Durante
   ese intervalo un 503 refresh pending es posible; no ocultarlo como cero hallazgos.
   Si persiste, revisar alcance y fuentes. Dos fuentes para el mismo endpoint exigen
   resolver cuál es autoritativa; no borrar índices ni escoger una automáticamente.
10. Probar API externa autenticada, rechazo sin clave/alcance y navegador real.

No hay replay histórico ni cambio de grupos, asignaciones, índices o claves de seal.
Ante un fallo conservar logs, staging y respaldos y detenerse para diagnóstico.
No inicializar OpenBao, borrar volúmenes ni restaurar a ciegas.

## Puerta de aceptación: lab02 antes de producción

Confirmar hostname, topología, deployment_id y versión de lab02 antes de ejecutar
comandos. No reutilizar direcciones, staging ni respaldos de otra instalación.

- Respaldo nuevo recuperable y descifrado comprobado; clave de seal separada.
- Preflight, upgrade, versiones y readiness completos; datos/cuenta protegida intactos.
- Reporte real por hostname con una y varias selecciones, totales completos y hojas
  Host > paquete. Confirmar la procedencia del namespace con inventario autenticado.
- Rechazo de otro tenant, namespace ajeno y dos fuentes ambiguas; no borrar índices.
- Resumen externo fresco y autenticado; comprobar el fin de refresh pending y rechazo
  sin credencial/alcance. Probar Word, Excel y correo con destinatarios autorizados.
- Guardar ACK, comentario y severidad/prioridad en varios casos. Medir por separado
  POST/PATCH y GET posteriores, en primera operación y repetidas, también mientras
  trabaja la correlación. Si hay espera, capturar bloqueos SQL sin cancelar sesiones.
- Verificar avance de checkpoints, sin errores ni duplicados ni replay histórico.

No compartir HAR sin sanear: puede contener cookies, tokens y datos de casos.
Solo tras revisar la aceptación de lab02, preparar un respaldo NUEVO y una ventana
separada para LAUFEY distribuido. Publicar no equivale a autorizar ese despliegue.
