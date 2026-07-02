**TRABAJO PRÁCTICO N° 2 — APRENDIZAJE AUTOMÁTICO 4**

**Versatilidad del flujo y dashboard de métricas**

*Continuación y evolución del TP1: del bot funcional al producto consumible*

**Fecha límite de presentación: a definir (estimada entre 30/06 y 07/07/2026) — Enviar por mail a lgiannasi@ies21.edu.ar**

**Contexto**

En el TP1 cada grupo construyó un asistente automático en n8n que consulta fuentes, las cura con un LLM y responde por Telegram. La consigna se enfocó en que el flujo existiera y conectara fuentes con un canal de salida. Eso resolvió el problema desde el lado técnico, pero todavía no es un producto: el usuario sólo puede mandar un comando rígido y el dueño de la app no tiene forma de medir si lo que entregamos funciona.

En este TP2 vamos a transformar ese bot funcional en un producto consumible. Dos cambios concretos:

* Versatilidad en el contacto con el usuario: el bot tiene que entender pedidos específicos (categoría, fecha, zona, intención) y no solo responder a un comando único.  
* Dashboard de métricas para el dueño de la app: alguien que paga por esto tiene que poder abrir una pantalla y ver qué usan los usuarios, cuántos vuelven, qué fuentes producen valor, dónde hay errores.

No se les pide rehacer el flujo del TP1. Se les pide extenderlo. El JSON entregado el 15/05 es el punto de partida; este TP2 suma capas encima.

**Su tarea**

Construir, sobre el bot del TP1, las dos capas siguientes:

**Eje 1 — Versatilidad del flujo**

Implementar un mecanismo de detección de intenciones que permita al usuario pedir cosas distintas en lenguaje natural o vía comandos estructurados. Como mínimo, el bot tiene que poder diferenciar:

* Categoría / tipo (música, teatro, cine, gastronomía, etc., según su caso de uso).  
* Rango temporal (hoy, este fin de semana, próxima semana, una fecha puntual).  
* Una tercera dimensión a elección: zona geográfica, rango de precios, modalidad presencial/virtual, idioma, etc.

Si la información del usuario es ambigua o incompleta, el bot debe repreguntar antes de responder. Si no, el flujo termina filtrando los resultados según los criterios detectados.

Implementaciones aceptadas (cualquiera de las tres, gratis): regex \+ Switch en n8n; LLM clasificador chico (Groq Llama 3.1 8B Instant devuelve JSON estructurado a costo cero); Inline Keyboard de Telegram con botones que arman la consulta.

**Eje 2 — Dashboard de métricas**

Construir un panel visible para el dueño de la app que muestre, como mínimo, los siguientes KPIs:

* Cantidad de queries por día / semana.  
* Usuarios únicos por período (queries totales no es lo mismo que usuarios distintos).  
* Top de intenciones o categorías más buscadas.  
* Tasa de respuestas con resultados vs respuestas vacías.  
* Latencia promedio de respuesta (cuánto tarda el bot en contestar).  
* Una métrica de fuentes: qué fuente produce más eventos o cuál falla más.

El dashboard se construye sobre una tabla de logs (queries\_log) que se alimenta desde el flujo de n8n: cada interacción del usuario inserta una fila con timestamp, identificador, intent detectado, resultado, latencia, etc. El esquema mínimo se define en el informe.

Implementaciones aceptadas (gratis): Looker Studio (ex Data Studio) conectado a Google Sheets o Supabase; Supabase Studio (incluido en free tier) con views SQL; HTML estático en GitHub Pages, Netlify free o Cloudflare Pages con Chart.js \+ supabase-js; pivot tables nativas de Google Sheets como mínimo viable.

**Qué eligen ustedes**

Mantienen el caso de uso del TP1 (no cambiar de tema). La herramienta de dashboard y el modelo de detección de intenciones son decisión del grupo, siempre respetando el stack mínimo y la regla de costo cero.

Único requisito de fondo: el dashboard tiene que servirle a alguien externo (el dueño de la app, un inversor, un cliente). Tiene que poder responder en 10 segundos: ¿el bot se usa?, ¿quiénes lo usan?, ¿qué piden?, ¿anda bien?.

**Stack mínimo a integrar (sumado al del TP1)**

Sobre el stack del TP1 (Schedule Trigger \+ Telegram Trigger \+ 2 HTTP Request \+ 2 Code \+ 1 IF \+ Telegram como nodo de salida), este TP2 suma:

* Un mecanismo de detección de intent (Code con regex, LLM clasificador, o Inline Keyboard).  
* Al menos un IF / Switch adicional para enrutar según el intent detectado.  
* Persistencia para logs: Google Sheets (gratis), Supabase free tier (500 MB Postgres), o equivalente.  
* Un nodo de escritura por cada interacción del usuario que registre la query en la tabla de logs.  
* Un dashboard visible (no contar como entregable un screenshot de Sheets — debe ser una superficie consultable).

**Regla de costo cero**

La institución no provee herramientas pagas y no están obligados a usar herramientas que requieran tarjeta de crédito. Toda la consigna se puede resolver con free tiers o software libre. Lista validada:

| Componente | Herramienta gratis | Límite del free tier |
| :---- | :---- | :---- |
| **Motor del workflow** | n8n self-hosted (Docker / Oracle Cloud Always Free / Hugging Face Space) | Sin límite |
| **LLM principal** | Groq (Llama 3.1 8B, Llama 3.3 70B, Whisper) | \~14.4k requests/día sin tarjeta |
| **LLM alternativo** | Google Gemini AI Studio (gemini-2.5-flash) | 1500 requests/día |
| **Scraping de Instagram** | Apify free tier | USD 5 de créditos/mes |
| **Scraping web** | HTTP Request \+ cheerio en Code | Sin límite (depende del sitio) |
| **Base de datos** | Supabase free tier | 500 MB Postgres \+ 50k MAU |
| **Persistencia simple** | Google Sheets | Sin límite práctico |
| **Dashboard sin código** | Looker Studio (ex Data Studio) | Gratis |
| **Dashboard con código** | GitHub Pages / Netlify free / Cloudflare Pages \+ Chart.js | Gratis |
| **Deploy n8n 24/7** | Render free \+ cron-job-org externo | Sleep cada 15 min sin tráfico, resuelto con cron |
| **Backup de workflows** | GitHub repo privado | Gratis |
| **APIs públicas Argentina** | DolarAPI, ArgentinaDatos, Open-Meteo | Gratis |

**Fases incrementales sugeridas**

**Fase 1 — Logging de interacciones**

Crear la tabla queries\_log (Sheets o Supabase) y conectar un nodo de escritura en el flujo existente del TP1. Cada vez que el bot responde, se inserta una fila. Esquema mínimo: ts (timestamp), chat\_id, mensaje\_raw, eventos\_devueltos (int), latencia\_ms (int). Sumar más columnas a gusto.

Validación de fase: revisar la tabla después de 10 mensajes de prueba. Tienen que aparecer las 10 filas con los datos correctos.

**Fase 2 — Detección de intenciones**

Sumar el mecanismo de intent: regex en Code, LLM clasificador o Inline Keyboard. El resultado del intent (categoria, fecha, zona u otra dimensión) debe quedar guardado en queries\_log y debe usarse para filtrar la búsqueda. Si el intent es ambiguo, el bot repregunta antes de responder.

Validación de fase: pedirle al bot tres cosas distintas (ej. "música este finde", "teatro hoy", "algo gratis cerca del centro") y verificar que cada respuesta esté filtrada correctamente.

**Fase 3 — Dashboard mínimo viable**

Construir el dashboard sobre queries\_log. Como mínimo, los KPIs listados arriba. Puede ser Looker Studio, Supabase Studio o un HTML estático. Tiene que ser una superficie consultable (URL o vista accesible), no una captura.

Validación de fase: abrir el dashboard sin ayuda de nadie y poder responder, en 10 segundos, las cuatro preguntas del dueño de la app (¿se usa?, ¿quiénes?, ¿qué piden?, ¿anda bien?).

**Fase 4 — Robustez y buenas prácticas**

Sumar al menos cuatro de las siguientes (todas se documentan en el decálogo de la devolución del TP1):

* Retry on fail en todos los HTTP críticos (3 intentos, 2 segundos).  
* IF de validación post-HTTP y post-LLM con rama de fallback que avise al usuario.  
* Idempotencia: dedup por external\_id antes de insertar logs o eventos.  
* Schema versioning del scraper: alerta si la cantidad de elementos extraídos cae bajo un umbral.  
* Error Trigger workflow nativo que avise al admin por Telegram si algo se rompe.  
* Onboarding (/start, /help) y comando admin (/metrics) que devuelva KPIs por Telegram.  
* Webhook secret\_token de Telegram para validar que las llamadas vienen de Telegram.  
* Backup del JSON del workflow en un repo privado de GitHub.

**Hitos semanales y regla de presentación**

Cada semana hay un checkpoint en el que cada grupo presenta lo avanzado, aunque sea parcial. Cada semana sin presentar avance descuenta 1 punto de la nota final integradora. La regla es acumulativa.

Excepción: si su TP1 ya cumplía los dos ejes propuestos (con persistencia, multi-intent y dashboard), pueden pedir confirmación del docente de que el TP1 cubre el TP2. En ese caso, los checkpoints semanales no aplican.

No se penaliza un avance "chico pero verdadero". Sí se penaliza un avance que sea copy-paste del anterior sin cambios reales.

**Hito intermedio — esquema antes de codear**

Antes de codear el dashboard, cada grupo entrega un esquema de una página con: qué tablas guarda, qué KPIs va a mostrar el dashboard, qué decisión toma el dueño de la app con cada KPI. Esto evita rehacer la base de datos a último momento y obliga a pensar en el usuario del dashboard.

**Entregables finales**

* Workflow(s) exportado(s) en .json desde n8n (botón "Download workflow"). Si el sistema se dividió en varios workflows, todos.  
* URL del dashboard visible y accesible al docente. Si requiere login, credenciales de prueba o un screen recording de 30 segundos navegándolo.  
* Esquema de la(s) tabla(s) de logs: nombre de tabla, columnas, tipos, descripción.  
* Informe en PDF o DOCX (máximo 5 páginas) con: caso de uso evolucionado, decisiones de diseño en intent \+ dashboard, KPIs elegidos y por qué, problemas enfrentados y cómo se resolvieron, capturas del dashboard.  
* Link al repo privado de GitHub donde tienen versionados los JSON de workflows (compartir acceso con el mail del docente).

**Rúbrica**

| Criterio | Peso |
| :---- | :---- |
| **Versatilidad del flujo (intent detection \+ filtrado \+ repregunta)** | 25% |
| **Tabla de logs bien diseñada (esquema completo \+ alimentación correcta)** | 15% |
| **Dashboard visible y funcional (KPIs requeridos \+ utilidad para el dueño)** | 25% |
| **Robustez y buenas prácticas (al menos 4 de la lista de Fase 4\)** | 15% |
| **Informe (claridad de decisiones, esquema, capturas)** | 10% |
| **Continuidad del TP1 (no romper lo que ya funcionaba)** | 10% |

**Bonus (hasta \+1.5 puntos sobre la nota final)**

* \+0.3: comando admin /metrics que devuelva los KPIs principales por Telegram (sin necesidad de abrir el dashboard).  
* \+0.3: A/B testing de prompts del LLM (dos versiones del system message, randomizar y comparar resultados en el dashboard).  
* \+0.3: persistencia de preferencias del usuario y recomendación proactiva (Schedule semanal que cruza preferencias guardadas con eventos nuevos).  
* \+0.3: feature de accesibilidad (audio in con Whisper Groq, audio out con TTS gratis, soporte multi-idioma).  
* \+0.3: feature creativa que sume valor real al usuario (sorpresa).

**Pistas y advertencias**

* Empiecen por Fase 1 (logging). Es la base de todo lo demás. Sin queries\_log no hay dashboard.  
* No usen herramientas pagas. Si tienen dudas sobre si algo es gratuito, pregunten antes de configurar tarjeta.  
* No expongan API keys en el JSON exportado. Usen Credentials de n8n. Lo mismo aplica para los tokens del dashboard si conecta a Supabase desde el navegador (anon key con RLS, no service\_role).  
* El dashboard cliente NUNCA debe usar la service\_role key de Supabase. Si la dejan en JS del cliente, cualquiera con DevTools del navegador tiene admin de la base.  
* El bot tiene que estar ACTIVO en n8n cuando lo pruebe el docente. Si está inactivo, el Telegram Trigger no escucha y el TP se considera no presentado hasta nuevo aviso.  
* Para evitar gastar créditos del LLM mientras desarrollan, usen pinData en los nodos (botón "Pin data") para probar con respuestas simuladas.  
* Cuiden el costo de los LLMs. Si todo va a Groq y Groq tiene rate limit por minuto, una racha de tests rompe el flujo. Implementen rate limiting básico con $getWorkflowStaticData.  
* El dashboard tiene que servir a alguien externo. Si abren la URL y no entienden qué muestra, está mal — diseñen pensando que lo va a usar alguien que no conoce el código.  
* La fecha límite y los hitos pueden ajustarse en clase. Cada semana sin presentar avance descuenta 1 punto de la nota final.

**Recursos sugeridos**

* Documentación oficial de n8n: docs.n8n.io  
* Supabase docs (free tier, RLS, RPC): supabase.com/docs  
* Looker Studio (Google) — conector nativo para Sheets  
* Chart.js — gráficos para el dashboard en HTML: chartjs.org  
* GitHub Pages para deploy gratis de HTMLs: pages.github.com  
* cron-job.org — disparador gratis externo para mantener Render activo  
* Hugging Face Spaces como host gratis de n8n (8 GB RAM)