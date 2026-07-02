# Fix: ECONNRESET / TLS en n8n sobre Hugging Face Spaces

## Causa

Hugging Face Spaces (plan gratuito) corre detrás de un proxy Cloudflare que
resetea conexiones TCP salientes hacia `api.telegram.org:443` antes de que
el handshake TLS se complete. Esto afecta al nodo nativo de Telegram de n8n
(que usa el SDK interno de node-telegram-bot-api con un socket directo).

## Solución A — Variables de entorno en HF Spaces (recomendada)

### Paso 1: Ir al Space de n8n en Hugging Face
https://huggingface.co/spaces/urielmendez-edu/mi-n8n-automatizacion

### Paso 2: Settings → Variables and secrets

Agregar estas variables (NO son secrets, son variables normales):

| Variable | Valor |
|---|---|
| `NODE_TLS_REJECT_UNAUTHORIZED` | `0` |
| `N8N_DEFAULT_BINARY_DATA_MODE` | `filesystem` |

> ⚠️ `NODE_TLS_REJECT_UNAUTHORIZED=0` deshabilita la validación del certificado TLS
> para las conexiones salientes de Node.js. Es aceptable en este contexto porque:
> - Hugging Face ya provee la capa TLS/HTTPS para el frontend
> - Las llamadas salientes van a APIs conocidas (Telegram, Supabase, Groq)
> - El plan gratuito no permite configurar certificados CA personalizados

### Paso 3: Rebuild del Space
Después de guardar las variables, HF Spaces hace rebuild automático del contenedor.
Esperar ~2 minutos y probar el bot.

---

## Solución B — Reemplazar nodo Telegram por HTTP Request (más robusta)

Si la Solución A no funciona, se puede reemplazar cada nodo de Telegram de
SALIDA por un nodo HTTP Request que llame a la API de Telegram directamente.
Esto evita el SDK nativo y usa el cliente HTTP genérico de n8n (más resiliente).

### Configuración del nodo HTTP Request sustituto:

- **Method:** POST
- **URL:** `https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage`
- **Send Body:** JSON
- **Body:**
```json
{
  "chat_id": "{{ $json.chatId }}",
  "text": "{{ $json.texto }}",
  "parse_mode": "Markdown"
}
```
- **Options → Timeout:** 30000 ms
- **Retry on fail:** true, 3 intentos, 5000ms entre intentos

### Nodos a reemplazar en el flujo:
1. `Telegram Enviar Respuesta1` → responde al usuario
2. `Telegram Repregunta Intent` → pide más info al usuario
3. `Telegram Responder Comando` → responde /start /help /metrics
4. `Telegram Error LLM` → avisa error al usuario
5. `Telegram: ETL Completado (Admin)1` → notifica al admin
6. `Telegram: ETL Sin Eventos (Admin)1` → notifica al admin

### Variable de entorno requerida:
En HF Spaces → Settings → Secrets, agregar:
| Secret | Valor |
|---|---|
| `TELEGRAM_BOT_TOKEN` | `<TU_TELEGRAM_BOT_TOKEN>` |

En n8n, referenciar con `{{ $env.TELEGRAM_BOT_TOKEN }}` en la URL del HTTP Request.

---

## Solución C — Usar Telegram Trigger pero enviar respuestas via webhook

El Telegram Trigger (entrada) generalmente funciona porque HF Spaces SÍ acepta
conexiones ENTRANTES (el webhook de Telegram llama a tu n8n). El problema es
solo con las conexiones SALIENTES (n8n llamando a api.telegram.org).

Por eso la Solución B funciona: el HTTP Request node usa el mismo motor que
los nodos de scraping (que SÍ funcionan), solo que apuntando a api.telegram.org.

---

## Verificación

Después de aplicar cualquiera de las soluciones, probar con:
1. Mandar `/start` al bot desde Telegram
2. Si responde → problema resuelto
3. Si sigue fallando → verificar los logs del Space en HF Spaces → Logs
