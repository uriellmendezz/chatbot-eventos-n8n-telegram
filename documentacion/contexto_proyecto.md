# Contexto del Proyecto: Chatbot Colo & ETL de Eventos en Córdoba

Este documento describe de manera detallada el propósito, la arquitectura de sistemas, los flujos de n8n y las integraciones con servicios externos de este proyecto. Su objetivo es servir como manual técnico de referencia para el desarrollo, mantenimiento y despliegue del sistema.

---

## 1. Arquitectura General del Sistema

El proyecto está diseñado bajo una arquitectura desacoplada basada en eventos y automatizaciones en la nube, optimizada para ejecutarse bajo límites de planes gratuitos.

```mermaid
graph TD
    subgraph Cliente y Canales
        User[Usuario de Telegram] <-->|Mensajes / Comandos| TelegramAPI[Telegram Bot API]
    end

    subgraph Hosting del Servidor de Flujos
        subgraph Hugging Face Spaces: n8n
            WebhookEndpoint[Webhook Genérico] <-- Webhook Entrante | TelegramAPI
            TriggerEtl[Schedule Trigger]
        end
    end

    subgraph Funciones Serverless
        VercelProxy[Proxy en Vercel: api/telegram]
    end

    subgraph Base de Datos Cloud
        Supabase[(Supabase: PostgreSQL)]
    end

    subgraph Proveedor de IA
        GroqAPI[Groq API: LLaMA Models]
    end

    %% Relaciones de salida
    WebhookEndpoint -->|Buffer & Procesamiento| IA_Colo[Agente de IA Colo]
    IA_Colo <-->|Consulta Eventos / Guarda Logs| Supabase
    IA_Colo -->|Petición de Chat / Herramientas| GroqAPI
    IA_Colo -->|Envío de Respuestas| VercelProxy
    VercelProxy -->|Redirección HTTP| TelegramAPI

    %% Relaciones de ETL
    TriggerEtl -->|Scraping de Sitios Web| Scraping[ETL Pipeline]
    Scraping -->|Estructuración con IA| GroqAPI
    Scraping -->|Upsert de Eventos / Limpieza| Supabase
    Scraping -->|Notificación Estado Admin| VercelProxy
```

### Tecnologías y Servicios de Terceros Utilizados

1.  **Hugging Face Spaces (n8n)**:
    *   Hospeda la instancia de automatización de n8n dentro de un contenedor Docker en su plan gratuito.
    *   **Desafío**: HF Spaces bloquea las conexiones de red TCP salientes directas hacia el dominio `api.telegram.org:443`.
2.  **Vercel (Proxy Intermedio de Telegram)**:
    *   Hospeda una función serverless (`api/telegram.js`) que funciona como proxy HTTP para evitar el bloqueo perimetral de Hugging Face.
    *   Las peticiones de salida desde n8n destinadas a Telegram se envían a Vercel, y esta redirige las peticiones a la API oficial de Telegram sin problemas de TLS o reinicio de conexiones (`ECONNRESET`).
3.  **Supabase (PostgreSQL Cloud)**:
    *   Almacena la base de datos persistente.
    *   Contiene la tabla `eventos` (caché de eventos activos en Córdoba) y la tabla `queries_log` (historial de interacciones de los usuarios con el bot, latencias e intenciones).
4.  **Groq API**:
    *   Provee inferencia de modelos de lenguaje de ultra-baja latencia.
    *   **LLaMA 3.3 70B** en el proceso de ETL para extraer eventos a partir de HTML crudo.
    *   **LLaMA 3.1 8B** en el chatbot interactivo para interpretar consultas y responder con carisma local.
5.  **Telegram Bot API**:
    *   Interfaz de comunicación directa con el usuario final.

---

## 2. Flujo A: ETL y Scraping de Eventos (Ejecución en Background)

Este flujo se ejecuta de manera automática cada **2 días** con el objetivo de recopilar, limpiar y centralizar eventos futuros en Córdoba Capital.

```
[Schedule Trigger] 
       │
       ├───► Rama A: RSS (Circuito Gastronómico, CBA Beat) ───────┐
       │                                                          ▼
       ├───► Rama B: HTML (Movida Electrónica, CBA Turismo) ──► [Groq LLaMA3.3] ──► [Merge & Filtrar] ──► [Upsert Supabase] ──► [Borrar Pasados] ──► [Notificar Admin]
       │                                                          ▲
       └───► Rama C: HTML/XHR (Atrápalo Actividades) ────────► [Groq LLaMA3.3] ──┘
```

### Detalles de Ejecución:
1.  **Activación**: Se dispara automáticamente cada 2 días mediante un nodo *Schedule Trigger*.
2.  **Ramas de Extracción**:
    *   **Rama A (RSS)**: Consulta canales RSS estructurados en XML. Se parsean los títulos, links y descripciones mediante un nodo *Code* directo.
    *   **Rama B (HTML Directo)**: Descarga el HTML plano de agendas de eventos. Un script limpia etiquetas innecesarias (`<script>`, `<style>`) y envía los primeros 8000 caracteres a un agente de **Groq (LLaMA-3.3-70b)** para estructurar y extraer los eventos en un formato JSON limpio.
    *   **Rama C (HTML/XHR)**: Similar a la Rama B, pero adaptada para consultar endpoints AJAX/XHR simulando cabeceras reales (User-Agent). También utiliza Groq para la conversión a JSON.
3.  **Consolidación y Limpieza**:
    *   Unifica todas las ramas en un solo flujo.
    *   Valida el esquema del JSON, filtra eventos duplicados o pasados, y trunca textos demasiado largos para evitar desbordar la base de datos.
4.  **Sincronización con Base de Datos**:
    *   Hace un **Upsert** (actualiza si existe, inserta si es nuevo) en la tabla `eventos` de Supabase usando el título del evento como identificador único.
    *   Ejecuta una consulta SQL para **borrar eventos antiguos** cuya fecha de realización sea menor a la actual, manteniendo la base de datos limpia y ligera.
5.  **Notificación**: Envía un reporte del estado del ETL (Completado / Sin Eventos Encontrados) al chat del administrador en Telegram vía el proxy de Vercel.

---

## 3. Flujo B: Chatbot Conversacional "Colo"

Este flujo se activa de manera pasiva y responde interactivamente a los mensajes enviados por los usuarios en Telegram.

### El Personaje: "Colo"
"Colo" es un asistente virtual simpático y servicial que habla con modismos típicos de Córdoba, Argentina (voseo, expresiones cordobesas). Su tono es cálido, relajado y de mucha "onda".

### Etapas del Flujo de Conversación:
1.  **Trigger de Entrada**: Un webhook genérico (`Telegram Webhook Input`) escucha las peticiones en la ruta `mi-chatbot-seguro/webhook`.
2.  **Buffer de Mensajes**: Un nodo de espera (5 segundos) agrupa mensajes seguidos enviados por un mismo chat para no procesar múltiples solicitudes de un usuario que escribe en partes (evitando sobrecostos en Groq).
3.  **Filtro de Comandos Especiales**:
    *   Detecta si el mensaje es un comando (`/start`, `/help`, `/metrics`).
    *   Si es comando, genera y envía una respuesta predefinida inmediatamente (ej. el menú de ayuda), registra el comando en Supabase y corta el flujo allí.
4.  **Clasificación de Intención (Intent Classifier)**:
    *   Un nodo de código analiza el mensaje mediante expresiones regulares (regex) e identifica tres dimensiones críticas:
        *   **Categoría**: gastronomía, electrónica, shows, deportes, cultura.
        *   **Rango de Tiempo**: hoy, fin de semana, esta semana, fecha puntual.
        *   **Zona Geográfica**: Güemes, Nueva Córdoba, Centro, Cerro de las Rosas, etc.
    *   Si no detecta categoría ni fecha, marca la consulta como **ambigua**.
5.  **Manejo de Ambigüedad**:
    *   Si es ambigua, el bot responde de forma amigable repreguntando qué desea buscar (mostrando opciones de categorías y zonas) y guarda la repregunta en los logs.
6.  **Agente de Inteligencia Actor (AI Agent Colo)**:
    *   Si la consulta es clara, entra en acción el agente LangChain con **Groq (LLaMA-3.1-8b)**.
    *   Tiene memoria de conversación (`Window Buffer Memory` de 2 turnos) para recordar preguntas previas.
    *   **Herramienta de Supabase**: El agente invoca la herramienta `Get many rows in Supabase` para leer eventos del catálogo. El agente filtra los eventos obtenidos utilizando las variables identificadas en la fase de clasificación.
7.  **Formateo y Envío**:
    *   Colo redacta la respuesta usando formato Telegram Markdown.
    *   Envía la respuesta al usuario a través del proxy de Vercel.
8.  **Registro de Auditoría (Logging)**:
    *   Guarda en la tabla `queries_log` de Supabase todos los detalles de la consulta: id del chat, mensaje enviado, intenciones detectadas, cantidad de eventos devueltos, latencia total del procesamiento en milisegundos y fecha.

---

## 4. Estructura de Datos en Supabase (Tablas Clave)

### Tabla: `eventos`
Contiene los eventos activos disponibles para consulta.
*   `id`: UUID (Primary Key, autogenerado).
*   `titulo`: VARCHAR (Identificador semántico principal del evento).
*   `fecha_original`: VARCHAR (Fecha tal cual figura en la web original, ej. "Sábado 12 de Octubre").
*   `fecha_iso`: TIMESTAMP (Fecha estandarizada para filtrados lógicos y limpiezas).
*   `categoria`: VARCHAR (shows, electronica, cultura, gastronomia, deportes).
*   `ubicacion`: VARCHAR (Lugar físico del evento).
*   `link`: VARCHAR (Enlace para comprar entradas o ver detalles).
*   `fuente`: VARCHAR (Web de origen del scraping, ej. "CBA Beat").
*   `descripcion`: TEXT (Sinopsis o detalles adicionales del evento).
*   `fuente_tipo`: VARCHAR (rss, html, xhr).

### Tabla: `queries_log`
Registra el historial de conversaciones y métricas de rendimiento.
*   `id`: UUID (Primary Key).
*   `chat_id`: VARCHAR (ID de chat de Telegram del usuario).
*   `ts`: TIMESTAMP (Marca de tiempo de la consulta).
*   `mensaje_raw`: TEXT (Mensaje de texto original enviado por el usuario).
*   `intent_categoria`: VARCHAR (Categoría clasificada o null).
*   `intent_fecha`: VARCHAR (Tiempo clasificado o null).
*   `intent_zona`: VARCHAR (Zona clasificada o null).
*   `intent_ambiguo`: BOOLEAN (Indica si requirió repregunta).
*   `es_comando`: BOOLEAN (Indica si fue comando del sistema `/start`, `/help`, `/metrics`).
*   `eventos_devueltos`: INTEGER (Cantidad de eventos que se presentaron al usuario).
*   `resultado_count`: INTEGER (Total de eventos devueltos).
*   `latencia_ms`: INTEGER (Tiempo total que tardó el chatbot en responder).
