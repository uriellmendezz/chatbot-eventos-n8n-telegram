# Contexto de Implementación: Proxy de Telegram en Vercel para n8n (Hugging Face Spaces)

## 1. Propósito del Componente
Este componente actúa como una **Serverless Function (Proxy Intermedio)** alojada en Vercel. Su objetivo exclusivo es evadir las restricciones de red perimetral (*Egress Filtering*), inspección profunda de paquetes (DPI) y fallas de negociación TLS (`ECONNRESET`) que ocurren al intentar conectar un nodo nativo de Telegram desde una instancia de n8n alojada en el plan gratuito de **Hugging Face Spaces**.

Al delegar la petición HTTP a Vercel, el tráfico saliente desde Hugging Face se procesa como una petición estándar hacia los servidores de AWS/Vercel (permitida), y es la infraestructura de Vercel la que realiza el *handshake* seguro con la API oficial de Telegram sin bloqueos.

---

## 2. Especificaciones de la Infraestructura

* **Proveedor de Hosting:** Vercel (Plan Hobby - Gratis)
* **Entorno de Ejecución:** Node.js (Serverless Architecture)
* **URL Base de la App:** `https://telegram-proxy-hb1r.vercel.app`
* **Ruta del Endpoint (Endpoint Path):** `/api/telegram`
* **URL Completa del Proxy:** `https://telegram-proxy-hb1r.vercel.app/api/telegram`

---

## 3. Código Fuente de la Solución (`api/telegram.js`)

El repositorio en GitHub o entorno local está estructurado con una carpeta raíz `api/` que contiene el controlador de la función. El código maneja cabeceras CORS de forma nativa y realiza el *forwarding* del payload:

```javascript
export default async function handler(req, res) {
  // Habilitar CORS para peticiones HTTP desde n8n
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // Manejar peticiones de pre-vuelo (OPTIONS)
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // Restringir el endpoint estrictamente a métodos POST
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Método no permitido. Usar POST.' });
  }

  // Extraer el token de seguridad del bot enviado por Query Parameter
  const { token } = req.query;

  if (!token) {
    return res.status(400).json({ error: 'Falta el parámetro "token" en la URL.' });
  }

  try {
    const telegramUrl = `https://api.telegram.org/bot${token}/sendMessage`;

    // Reenvío asincrónico del Body (JSON) recibido de n8n hacia Telegram
    const response = await fetch(telegramUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(req.body),
    });

    const data = await response.json();

    // Retornar a n8n el código de estado y la respuesta exacta de Telegram
    return res.status(response.status).json(data);

  } catch (error) {
    return res.status(500).json({ 
      error: 'Error interno en el proxy de Vercel', 
      details: error.message 
    });
  }
}