# Uso rapido de las piezas nuevas

Este paquete agrega tres piezas al proyecto ARKAIOS Wii:

1. `server/local-importer.mjs` + `Importar_Mis_Roms.bat`
   Cataloga archivos locales que ya existen en tu PC/USB/SD. No descarga ROMs.

2. `mcp/arkaios-wii-mcp-server.mjs` + `Iniciar_Arkaios_MCP_Server.bat`
   Expone el servidor local ARKAIOS como herramientas MCP para agentes compatibles.

3. `protocol/arkaios-wii-catalog-item.schema.json`
   Define cada item del catalogo con `source_type`, separando `homebrew` de `user_backup`.

## Uso local

1. Inicia el servidor base con doble clic en `Iniciar_Arkaios_Node_Server.bat`.
2. Ejecuta `Importar_Mis_Roms.bat` y escribe la ruta donde estan tus archivos locales.
3. Para usar MCP, ejecuta `Iniciar_Arkaios_MCP_Server.bat` y deja esa ventana abierta.

## Cliente MCP

En un cliente compatible, registra el servidor asi, ajustando la ruta si tu repo esta en otra carpeta:

```json
{
  "mcpServers": {
    "arkaios-wii": {
      "command": "node",
      "args": ["C:/ARKAIOS/wii-retroarch-tools/mcp/arkaios-wii-mcp-server.mjs"],
      "env": {
        "ARKAIOS_NODE_BASE_URL": "http://127.0.0.1:8787"
      }
    }
  }
}
```

## Que no hace

- No descarga ROMs comerciales.
- No automatiza sitios de distribucion de ROMs.
- No usa API keys.
- No comparte archivos entre usuarios; solo cataloga metadata local.
