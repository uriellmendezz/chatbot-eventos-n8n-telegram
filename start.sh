#!/bin/sh

# Imprimir información del arranque
echo "=== Auto-importación de workflows en n8n ==="

# Asegurar que el directorio de la base de datos existe
mkdir -p /home/node/.n8n

# Importar workflow de forma automática
if [ -f "/home/node/workflow.json" ]; then
  echo "Cargando el flujo JSON en la base de datos de n8n..."
  n8n import:workflow --input=/home/node/workflow.json
else
  echo "Advertencia: No se encontró el archivo /home/node/workflow.json"
fi

# Iniciar servidor n8n
echo "Iniciando servidor n8n en puerto 7860..."
exec n8n
