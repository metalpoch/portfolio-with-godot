# Godot 4.7 · Experiencias Web 2D — Agent Preset

Bundle local que declara el preset `godot-web-orchestrator` para el perfil `web` de DSH.

## Qué contiene

| Archivo | Rol |
|---|---|
| `package.json` | Manifiesto del bundle; apunta al patch. |
| `cordis.patch.yml` | Declaración del preset: persona + 16 filas de plugins. |

La persona es el system prompt del *Agente Orquestador* de experiencias web 2D en Godot 4.7, conservado **verbatim** (10 494 caracteres). El patch es la fuente de verdad instalada; si editas la persona, edita el bloque `prefix` de `cordis.patch.yml` y reinstala el bundle.

## Tools incluidas

- Shell: `bash` (Linux/macOS) o `pwsh` (Windows), más `jobs` para servidores/procesos en background.
- Archivos: `read`, `write`, `edit`, `read_image`, `glob`, `grep`.
- Web: `web_search`, `web_fetch` (documentación de Godot, headers, hosting).
- Orquestación: `subagent` + `list_agents` + `send_message` + `interrupt_agent`.
- Trabajo: `todo_write`, `ask_user_question`, `present`, `skill`.
- Contexto largo: compactación y poda de resultados.

## Subagentes

El orquestador lanza hijos con `agentPreset: standard`, de modo que **no heredan** la persona de orquestador. Cada llamada debe llevar un brief autocontenido (los hijos no ven esta conversación). Con el `maxDepth` por defecto (1), los hijos no pueden delegar a su vez.

## Instalar

Desde el perfil `web`, con el plugin manager:

```
plugin_manager(action: "install_bundle",
               target: "/home/poch/Godot/pochland.zip/preset-godot-web-orchestrator")
```

La instalación es un cambio de perfil (afecta a todas las sesiones) y requiere aprobación. Tras instalarlo, el preset aparece en el selector como **Godot 4.7 · Experiencias Web 2D**.

## Verificar

```
plugin_manager(action: "list_plugins")
```

Busca la fila `preset-godot-web-orchestrator` con `fiberPhase` activo y sin diagnóstico. Para validar el comportamiento, crea una **sesión nueva** y selecciona el preset; las sesiones existentes conservan su composición.

## Actualizar o quitar

- Cambiar la persona: editar `cordis.patch.yml` y reinstalar el bundle (o `set_bundle` para recargarlo).
- Desactivar: `plugin_manager(action: "set_plugin", target: "preset-godot-web-orchestrator", enabled: false)`.
- Quitar: `plugin_manager(action: "remove_bundle", target: "@local/dsh-godot-web-orchestrator")`.

## Notas de diseño

- `persona.complete: false`: la persona sustituye la identidad por defecto, pero conserva la guía de tools y el runtime context del harness.
- `includeRuntimeContext: true`: el agente recibe cwd, hora y modelo.
- No se incluyen `subagent_fork` ni `workflow` para evitar que los hijos hereden la persona del orquestador o que el fan-out quede fuera de control; el paralelismo se hace con varias llamadas a `subagent` en un mismo mensaje.
- No se incluyen goals, scheduling ni plan mode: el flujo del prompt ya define las fases.
