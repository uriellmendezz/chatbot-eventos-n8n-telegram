#!/bin/sh

# Imprimir informaciÃ³n del arranque
echo "=== Auto-importaciÃ³n de workflows en n8n ==="

# Asegurar que el directorio de la base de datos existe
mkdir -p /home/node/.n8n

# Importar workflows de forma automÃ¡tica
if [ -d "/home/node/workflows" ]; then
  echo "Cargando flujos JSON en la base de datos de n8n..."
  n8n import:workflow --separate --input=/home/node/workflows
else
  echo "Advertencia: No se encontrÃ³ la carpeta /home/node/workflows"
fi

# Iniciar servidor n8n
echo "Iniciando servidor n8n en puerto 7860..."
exec n8n
