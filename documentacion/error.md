# Diagnóstico Técnico: Falla de Conexión TLS (ECONNRESET) en n8n sobre Hugging Face Spaces

## 1. Resumen del Problema
* **Síntoma:** El nodo nativo de Telegram (`sendMessage`) en n8n falla de manera consistente arrojando el error: `The connection to the server was closed unexpectedly, perhaps it is offline.`
* **Código de Error HTTP:** `ECONNRESET`
* **Mensaje de Error Crudo (Raw):** `Client network socket disconnected before secure TLS connection was established`
* **Entorno de Infraestructura:** n8n v2.26.7 ejecutándose en un contenedor Docker sobre la plataforma **Hugging Face Spaces (Plan Gratuito)**.

---

## 2. Análisis del Entorno y Logs del Sistema

### Fase A: Estabilización del Servidor Express (Solucionado)
Inicialmente, los logs del contenedor arrojaban excepciones repetitivas de validación:
```text
ValidationError: The 'X-Forwarded-For' header is set but the Express 'trust proxy' setting is false (default).
code: 'ERR_ERL_UNEXPECTED_X_FORWARDED_FOR'