# SOC Operations 0.1.169

Actualización de instalaciones existentes: [guía LAUFEY 0.1.168 → 0.1.169](upgrade-0.1.169-laufey.md).

## Correcciones

- Playbooks orientativos: las tareas pendientes no impiden cierre manual ni aprobación de cierre.
  Se conservan snapshots existentes, notas, evidencias e historial; no se necesita migración.
- Selección múltiple: identificador estable por índice y documento para ambos selectores de eventos.
- Kanban: texto y etiquetas explícitos con contraste legible en temas claro y oscuro.
- Automatización de vulnerabilidades: conserva evidencias autoritativas de ausencia, observación,
  política opt-in y severidad baja/media; la guía manual no constituye otra barrera de cierre.

## Versiones y validación

Instalador 0.1.169, API/worker/agente 0.1.119, plugin 0.1.100;
build `0.1.100-case-guidance-selection-contrast`, esquema `a2c8e4f719b6` sin migración nueva.
569 pruebas backend, 15 omitidas; 38 frontend. Nueve diagnósticos de tipos preexistentes,
sin nuevos. Fuente/wheel/imagen concordantes, dependencias de imagen sanas, ambos plugins
compilados y contenido gzip verificado. Pruebas locales no sustituyen aceptación en producción.

## Huellas SHA-256

| Artefacto | SHA-256 |
| --- | --- |
| SHA256SUMS externo | `661cc8d1e628d4aae0a465718f97b50703f54c5ed6139f66710431ec10804150` |
| TAR cifrado | `4915dc9e0d7f4a14cd609bd0909581f59fb4c642303efc05d9b2430b05e8c540` |
| TAR descifrado | `e20388eee69934a3474f84567bbe958cf30ccbe030aef83652ee3f4e693be313` |
| soc-operations-install | `5b2641f7be1ae11b53a8b633aa5ef31768e4def2a478588be7746a79febaf3fa` |

Solo se publican el TAR cifrado y el manifiesto; nunca código privado, identidad age,
credenciales, configuración real ni respaldos de LAUFEY. Se usa el mismo destinatario público age.
Los 48 artefactos internos se verifican por SHA256SUMS. 0.1.168 permanece inmutable.
No modifica Wazuh, custodia OpenBao, topología, HAProxy/Coraza ni CSP. El 401 de `/api/request`
y la caché externa no se corrigen en este release. No hay rollback global automático.
