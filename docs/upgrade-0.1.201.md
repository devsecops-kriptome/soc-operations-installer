# Actualización a SOC Operations Installer 0.1.201

Destino: instalador 0.1.201; API, API externa, worker y agente 0.1.144;
plugin 0.1.122; esquema f2c6a8d90173. AIO y distribuido.

## Preparación

1. Registrar host, topología, deployment_id, direcciones, versiones, salud,
   conteos y configuración. Resolver readiness antes de actualizar.
2. Crear y verificar un respaldo nuevo de PostgreSQL, OpenBao, objetos versionados,
   reportes, snapshots y configuración. Custodiar auto-unseal por separado.
3. Descargar el paquete age y SHA256SUMS de v0.1.201. Comparar primero el hash
   de SHA256SUMS con las notas del release; verificar el paquete cifrado.
4. Descifrar con la identidad age autorizada, nunca en argumentos ni registros.
   Verificar el hash del tar en claro. No confundir las dos filas del manifiesto:
   el tar sin cifrar se obtiene al descifrar; no es un asset público descargable.
5. Validar rutas y tipos del tar; extraer en staging nuevo root, verificar
   SHA256SUMS interno y ejecutar preflight para el destino exacto.
6. En distribuido actualizar primero el agente del Manager a 0.1.144, conservando
   IP, DNS, TLS y configuración. En AIO se reconcilia el agente local.

## Ejecución

Ejecutar upgrade, no apply ni una instalación limpia, desde el staging verificado
0.1.201. Usar --staging-root, --service-address y --external-proxy-cidr propios
del despliegue; conservar deployment_id, credenciales y topología persistida.
No copiar direcciones de otros entornos ni actualizar componentes aisladamente.

Desde 0.1.199 se aplican las migraciones b7d3e9f21a60 y f2c6a8d90173.
Se crea la persistencia de recuperación y se reconoce el método de seis campos;
no se reescribe evidencia original ni se reparan casos automáticamente.
El candidato local 0.1.200 no es un paso previo obligatorio.

## Aceptación

- Confirmar phase=complete, componentes 0.1.144, plugin 0.1.122, esquema
  f2c6a8d90173 y UI build 0.1.122-vulnerability-fast-hosts-and-history.
- Comprobar readiness, gateway, OpenBao sin sellar, auto-unseal, cuenta protegida,
  datos y conservación de la configuración propia del destino.
- Verificar RLS forzada, permisos y trigger append-only. La actualización por sí
  sola no debe crear filas de recuperación histórica.
- Dashboard debe abrir con siete días. Hosts debe indicar la fecha/procedencia
  del último corte confirmado y conservarlo durante otra captura. Un host nuevo
  sin métricas debe mostrarse pendiente, no con un cero inventado.
- Comprobar filtros, cambios de tenant, respuestas obsoletas y lectura con todos
  los roles autorizados, sin conceder escrituras ni acceso a otro tenant.
- Verificar generación y descarga de reportes Word/Excel de un host autorizado
  con datos actuales y totales por criticidad. Rechazar hosts/reportes ajenos.
- Comprobar las próximas capturas de 00:00/12:00 America/Lima, seis cortes completos
  y métricas por 90 días. Abrir las vistas no debe generar snapshots nuevos.
- Probar la API externa de historial con una clave autorizada del tenant y los
  filtros correspondientes, sin ampliar los alcances de claves existentes.

## Recuperación histórica de casos: operación separada

Generar un plan nuevo de solo lectura para el tenant con el servicio incluido,
collect_plan. Revisar candidatos y exclusiones, cantidad y plan_sha256, y custodiar
el plan fuera de Git con permisos privados. No reutilizar huellas ni cantidades
de diagnósticos anteriores. No publicar referencias de alertas o casos del cliente.

La aplicación mediante apply_plan requiere el hash y la cantidad revisados,
contexto interno de servicio autorizado y una transacción nueva. Confirmar solo
si toda la operación termina correctamente; cualquier error requiere rollback.
Después verificar auditoría, MTTD y conservación de evidencias y relojes originales.
Sin objetivo histórico verificable solo se recupera duración, no cumplimiento SLA.
No ejecutar SQL directo para eludir el servicio, RLS, triggers o hashes.

Si falla una fase, conservar evidencias y revisar el estado antes de reintentar.
No restaurar datos ni volver al runtime anterior sin evaluar las migraciones y
el punto recuperable. No borrar paquetes ni respaldos para completar el upgrade.
Publicar esta versión no ejecuta ninguna operación en el servidor.
