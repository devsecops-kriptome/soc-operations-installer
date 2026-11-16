# Pruebas AIO y actualización al candidato 0.1.207

No ejecutar todavía comandos de instalación en producción. Este candidato se
publica como pre-release para un AIO de pruebas; 0.1.206 sigue siendo estable.

## Antes de instalar

1. Identificar el hostname del AIO, Ubuntu, Wazuh, OSD, versiones SOC Operations,
   topología, salud, memoria y espacio. No asumir que coincide con otro servidor.
2. Si existe una instalación, registrar deployment_id, direcciones, proxy, certificados,
   configuración de módulos y montajes reales. Crear un respaldo nuevo verificado de
   PostgreSQL y roles, OpenBao, versiones S3, reportes, snapshots y configuración.
   Custodiar la clave auto-unseal por separado; no borrar respaldos anteriores aún.
3. Descargar únicamente los assets del tag v0.1.207: TAR age y SHA256SUMS. Comprobar
   el manifiesto específico del candidato, sin usar el SHA256SUMS raíz de la rama main,
   que corresponde a la versión estable. También está en
   [checksums/SHA256SUMS-0.1.207](../checksums/SHA256SUMS-0.1.207).
4. Descifrar con la identidad age del gestor autorizado, oculta, sin guardarla en
   archivos ni argumentos. Verificar el hash del TAR en claro antes de extraer.
5. Verificar rutas, tipos, enlaces y hashes; extraer en un staging nuevo protegido.
   No mezclar helpers o plugins de versiones distintas ni sustituir el instalador aún.
6. Ejecutar `preflight` con la topología real/persistida. Si falla, conservar evidencia
   y detenerse: no omitir controles ni actualizar paquetes del host sin autorización.

## Instalación o actualización

Una instalación existente usa el flujo `upgrade`, nunca inicialización de OpenBao,
borrado de volúmenes o una instalación limpia sobre datos. Conservar la secuencia
de reconciliación del agente del Manager antes del runtime y registrar los códigos
de salida. En un AIO nuevo se usa la guía normal, con las versiones del candidato.

La operación recrea componentes y puede interrumpir servicio. La publicación en
GitHub no autoriza a ejecutarla: confirmar la ventana en el servidor de pruebas.
No se recuperan ni recalculan SLA históricos como parte de esta aceptación.

## Activos, después de validar la instalación

El módulo viene apagado. Seguir `ASSETS-AIO-0207.txt` del paquete para preparar:

- Identidad Indexer dedicada al backend y restringida a `wazuh-assets-*`, sin acceso
  a alertas ni credenciales de administrador. Revisar roles efectivos y comodines.
- Credencial en OpenBao, usando el procedimiento seguro del operador.
- CA públicas verificadas en el directorio preparado por el instalador, sin claves privadas.
- URL HTTPS del Indexer alcanzable desde contenedores y coincidente con el certificado.
  No usar localhost del contenedor para alcanzar el host ni desactivar verificación TLS.
- Orígenes HTTPS de conectores permitidos por el operador. No son URLs libres por tenant.

Solo entonces habilitar Activos y recrear los componentes en una ventana controlada.
No habilitar programaciones hasta revisar una importación manual de cada origen.

## Aceptación mínima del AIO

Verificar salud y versiones, datos, configuración, cuenta protegida, ausencia de reinicios
en bucle y conservación de montajes persistentes. Comprobar que Activos siga apagado
antes de activarlo deliberadamente. Después usar dos tenants sintéticos para probar
aislamiento, perfiles, CSV, coincidencias ambiguas, revisiones concurrentes y correo.

Confirmar que un caso nuevo se enriquece sin modificar sus alertas, analista, estado
o hitos. Probar caída del Indexer, error del conector y pausa de programación. Probar
las lecturas externas con claves autorizadas y rechazo de claves sin alcance de tenant.
Incluir y restaurar los índices de Activos antes de aprobar su uso fuera del laboratorio.

Conservar evidencia privada y no compartir tokens, identidades age, claves TLS ni datos
reales en incidencias públicas. La vuelta a una versión anterior requiere evaluar el
respaldo coordinado; no apuntar binarios antiguos a datos ya migrados sin validación.
