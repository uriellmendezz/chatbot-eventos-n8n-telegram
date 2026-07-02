#!/bin/sh

# Imprimir información del arranque
echo "=== Auto-importación de workflows en n8n ==="

# Asegurar que el directorio de la base de datos existe
mkdir -p /home/node/.n8n

# Importar workflows de forma automática
if [ -d "/home/node/workflows" ]; then
  echo "Cargando flujos JSON en la base de datos de n8n..."
  n8n import:workflow --separate --input=/home/node/workflows
else
  echo "Advertencia: No se encontró la carpeta /home/node/workflows"
fi

# Iniciar servidor n8n
echo "Iniciando servidor n8n en puerto 7860..."
exec n8n
