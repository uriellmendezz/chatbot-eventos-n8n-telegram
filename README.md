---
title: Chatbot Eventos N8N Telegram
emoji: 🤖
colorFrom: blue
colorTo: green
sdk: docker
pinned: false
---

# Chatbot Eventos N8N Telegram

Este repositorio contiene la configuración y flujos para desplegar una instancia de **n8n** en **Hugging Face Spaces** utilizando Docker, con el fin de ejecutar un chatbot conversacional de Telegram llamado **"Colo"** y un pipeline de ETL automatizado para eventos en Córdoba, Argentina.

## Estructura del Proyecto

*   `Dockerfile`: Configuración del contenedor Docker para ejecutar n8n en Hugging Face Spaces.
*   `start.sh`: Script de arranque del contenedor para importar automáticamente los flujos.
*   `workflow.json`: Contiene el flujo de n8n exportado.
*   `database/`: Scripts de inicialización de la base de datos PostgreSQL en Supabase.
*   `index.html`: Panel web / dashboard de eventos.
*   `dashboard.html`: Vista de respaldo del panel de eventos.
*   `documentacion/`: Documentación técnica detallada del proyecto.

Para más detalles sobre la arquitectura de sistemas y el funcionamiento de los flujos, consulta la [Documentación del Contexto del Proyecto](documentacion/contexto_proyecto.md).
