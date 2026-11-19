# Actualización controlada a 0.1.209

Candidato para corregir la navegación de 0.1.208. Publicar no actualiza servicios.
No usar esta entrega para degradar un servidor con el prototipo 0.1.207 sin revisar
antes sus datos y configuración. Usar el flujo upgrade, no instalación limpia.

1. Confirmar host, versión, topología, readiness, espacio, ventana y reversión.
2. Crear y verificar un respaldo nuevo de PostgreSQL/roles, OpenBao, objetos,
   reportes, snapshots y configuración. Custodiar auto-unseal por separado y cifrar.
   Un respaldo en caliente no equivale a una instantánea atómica entre servicios.
   Una copia solo local no protege frente a pérdida del servidor; una restauración
   no probada sigue siendo una limitación.
3. Descargar de la release 0.1.209 `SHA256SUMS` y
   `soc-operations-0.1.209.tar.gz.age`. Verificar el cifrado antes de descifrar.
4. Introducir la identidad autorizada con entrada oculta, nunca en argumentos,
   historial ni chat. Verificar el hash del TAR claro antes de abrirlo.
5. Revisar rutas, tipos y duplicados del TAR. Extraer en staging nuevo y verificar
   SHA256SUMS internos. No sobrescribir el instalador activo antes del preflight.
6. Ejecutar la actualización guiada para la topología real, con confirmación
   explícita y registros privados. Puede reiniciar componentes; no interrumpir.
7. Confirmar instalador 0.1.209 completo, runtime/agente 0.1.151, plugin 0.1.129,
   OSD correcto, esquema d8a215c963b7, identidad de imagen y readiness. Docker puede
   informar ID de manifiesto o configuración; contrastar la identidad correspondiente.
8. Verificar conservación de datos, huellas históricas y configuración. Mantener
   el estado previo de Threat Radar; no deshabilitarlo por estar habilitado por el operador.

## Aceptación autenticada del menú

Comprobar con identidades existentes autorizadas de cada rol, sin cambiar roles
para forzar la aceptación. Probar Global, tenant autorizado y tenant sin acceso.

- Mantener abierto más de 90 segundos: los ciclos de 5/30 segundos no deben
  hacer desaparecer enlaces autorizados ni mostrar enlaces prohibidos.
- Navegar entre vistas y cambiar Global/tenant repetidamente. Contrastar enlaces
  y rutas directas con los permisos efectivos del perfil y del backend.
- Ingeniería: Calendario operativo ausente y acceso directo rechazado; los menús
  de administración solo donde correspondan. SOC Manager no obtiene Calendario
  operativo por mezclar roles. La administración central tiene alcance propio.
- Analista, Junior, Auditor y demás perfiles: solo sus vistas y acciones permitidas;
  no trasladar permisos de tecnologías o Decoder Studio desde otro tenant.
- Si se prueba una revocación, hacerlo con una cuenta de prueba autorizada. Las
  respuestas tardías no deben devolver privilegios; no modificar la cuenta protegida.
- Verificar plugin 0.1.129 y marcador `0.1.129-navigation-state-eager-app` servido.
  Revisar carga de JavaScript y consola sin errores de montaje. Si persisten,
  conservar cabeceras/diagnósticos y revisar origen, proxy y caché sin relajar CSP.

No repetir planes de recuperación de alertas, hitos, suplementos ni cálculos
agregados históricos de SLA. No hay corrección SQL automática en esta entrega.

Ante cualquier fallo, detener la aceptación, conservar evidencia y revisar el
procedimiento de reversión con los respaldos e imágenes previos verificados.
No borrar volúmenes, reinicializar OpenBao ni improvisar cambios de permisos.
