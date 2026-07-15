@echo off
cd /d "%~dp0"
if not exist node_modules\@modelcontextprotocol\sdk (
  echo Instalando dependencias del servidor MCP...
  call npm install
)
echo.
echo Iniciando servidor MCP de ARKAIOS Wii...
echo Deja esta ventana abierta mientras uses tu agente IA.
node mcp\arkaios-wii-mcp-server.mjs
pause
