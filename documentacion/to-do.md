**Méndez, Uriel Emiliano**

**Lo que ya tenés resuelto:**

* Hugging Face Space free tier (8 GB RAM) — buena elección, sin gastos.  
* Supabase free con esquema enriquecido (fecha\_iso, fuente\_tipo).  
* Pipeline paralela en 3 ramas (RSS/HTML/XHR) con estrategia antibloqueo.  
* Agente "Colo" con SupabaseTool — el LLM consulta la DB en runtime.  
* Workflow activo, cero hardcodes.

**Próximo paso obligado — dashboard (todo gratis):**

* Opción A más rápida: Supabase Studio (incluido en free tier) → crear views SQL para KPIs (queries por día, intents top, latencia p50/p95) → exportar a CSV o usar las charts nativas.  
* Opción B nivel producto: HTML estático en GitHub Pages o Netlify free \+ supabase-js \+ Chart.js. \~30 min de trabajo.  
* Tabla queries\_log que falta crear: id uuid, ts timestamptz, chat\_id text, mensaje text, intent\_detectado text, fuente\_resuelta text, resultado\_count int, latencia\_ms int, tokens\_in int, tokens\_out int.

**Buenas prácticas a profundizar:**

* RLS en Supabase: tu agente accede vía SupabaseTool con service\_role. El dashboard NO debe usar la misma key. Crear policies separadas para anon role (solo SELECT en views agregadas, no en tablas crudas).  
* Indexar en Postgres: CREATE INDEX ON events(categoria, fecha\_iso); CREATE INDEX ON queries\_log(ts DESC); Tu free tier no se queja por índices.  
* Particionado lógico por fecha: si los queries\_log crecen, separar en tablas mensuales con CHECK constraint. Optional pero buena praxis.  
* Antibloqueo profundizado: rotación de User-Agents desde una lista (random por request), no un User-Agent fijo. Algunos sitios bloquean User-Agents conocidos.  
* Idempotencia del upsert: tu ON CONFLICT está bien. Verificá que la unique key sea estable — si usás link como PK, redirects rompen dedup. Mejor un hash(titulo+fecha+lugar).  
* Prompt caching manual: tu system message de "Colo" es largo. Para reducir tokens, guardalo en $getWorkflowStaticData y solo pasalo en la primera interacción del usuario; en las siguientes, usar Memory.

**Versatilidad para profundizar:**

* Multi-intent en una sola consulta: "te aviso de teatro este finde y música el viernes" → tu agente con SupabaseTool puede manejarlo si el system prompt lo guía a hacer múltiples SELECTs.  
* Slots faltantes: si el usuario pide "eventos" sin categoría, repreguntar antes de buscar. UX de bot pro.

**Reglas de juego**

* Las herramientas usadas DEBEN ser gratuitas o free tier. La institución no provee herramientas pagas y los alumnos no están obligados a gastar de su bolsillo.  
* Toda sugerencia técnica está validada contra el stack gratis disponible: n8n self-hosted, Groq, Gemini AI Studio, Apify free, Supabase free, Google Sheets, Looker Studio (ex Data Studio), Render free, Oracle Cloud Always Free, Hugging Face Spaces, Netlify free, Cloudflare Pages, GitHub Pages, GitHub privado, ngrok free.  
* Tienen 2-3 semanas para desarrollar los dos ejes de la propuesta nueva: (a) versatilidad en pedidos del usuario; (b) dashboard con métricas para el dueño de la app.  
* Lo que sí es exigible es la corrección de los errores señalados en la devolución del 15/05 (hardcodes, falta de Schedule, activación del workflow). Eso debió corregirse.

**Decálogo de buenas prácticas técnicas (todo gratis)**

***Aplica a todos los alumnos. Sirve como guía durante las próximas semanas y como rúbrica de auto-revisión.***

* **1\. Secretos fuera del código.** Toda API key, token o webhook secret va en n8n Credentials (HTTP Header Auth, Bearer Auth, OAuth2). Si el JSON exportado tiene la cadena del token, está mal. Variables de entorno ($env.X) para URLs/configs no-secretas. Costo: cero.  
* **2\. Idempotencia.** Un workflow corrido 5 veces debe producir el mismo resultado. Implementar con dedup por external\_id (URL, shortcode, hash del contenido). Usar $getWorkflowStaticData("global") o una columna unique en Supabase/Sheets. Sin esto, el bot manda eventos duplicados o duplica filas en cada ejecución.  
* **3\. Validación en cada borde (fail-safe defaults).** IF después de cada HTTP que verifique status, longitud no vacía, formato esperado. IF después del LLM que valide que la respuesta tenga el formato pedido (ej. contiene "Evento:"). Si falla, rama de fallback con mensaje útil al usuario, no silencio.  
* **4\. Retry con backoff.** retryOnFail \= true, maxTries \= 3, waitBetweenTries \= 2000ms en todo HTTP externo. Mejor todavía: backoff exponencial (2s, 4s, 8s) en Code node si la API tiene rate limits.  
* **5\. Logs estructurados.** A Google Sheets (gratis) o Supabase free. Columnas mínimas: timestamp ISO, trace\_id (UUID por interacción), user\_id, level (INFO/WARN/ERROR), event\_type, payload\_json, latency\_ms. Esto es la base del dashboard.  
* **6\. Rate limiting básico.** Para no agotar Groq/Gemini/Apify free tier. Con $getWorkflowStaticData mantener un contador por chatId y por día. Si supera N queries/día, responder amablemente "ya te respondí mucho hoy, mañana sigo".  
* **7\. Webhook security.** Telegram permite secret\_token en setWebhook. Validarlo en el primer nodo (IF que verifique header X-Telegram-Bot-Api-Secret-Token). Sin esto, cualquiera que conozca tu URL pública mandó datos arbitrarios al flujo.  
* **8\. Schema versioning del scraper.** Si Cordoba turismo cambia el HTML, el cheerio se rompe en silencio. Code node simple que verifique que se encontraron al menos N elementos. Si encuentra 0 cuando esperaba 15, log nivel ERROR y avisar al admin por Telegram.  
* **9\. Graceful degradation.** Si una fuente cae, el bot sigue funcionando con las otras. Merge no espera a todas — el Code node aguas abajo descarta los items vacíos y procesa lo que llegó. Mejor cero eventos respondidos que crash silencioso.  
* **10\. Anonimización PII en logs.** No guardar nombre, apellido ni datos privados en los logs si no son necesarios. Si guardás user\_id, usá el chatId de Telegram (es un número, no es nombre). Para correlaciones, hashear con sha256 antes de loguear.  
* **11\. Backup de workflows en GitHub.** Exportar el JSON cada cambio significativo y subir a un repo privado de GitHub (gratis). Si n8n se rompe o tu Docker se cae, los workflows son recuperables. Costo: cero.  
* **12\. Testing con pinData.** n8n permite "pin" datos de prueba en cada nodo (botón "Pin data"). Pegar una respuesta de Apify de ejemplo y probar el flujo sin gastar créditos. Esencial para iterar sin agotar el free tier.  
* **13\. Error Trigger workflow.** Un workflow secundario que escucha errores del principal y manda alerta por Telegram al admin. n8n lo soporta nativamente con "Error Trigger". Gratis y obligatorio para producción.  
* **14\. Onboarding y comandos de descubrimiento.** /start con mensaje de bienvenida explicando qué puede hacer el bot. /help con la lista de comandos. /about con créditos. Esto NO es opcional — un bot sin onboarding pierde usuarios en el primer mensaje.  
* **15\. Cost monitoring sin gastar.** Loguear tokens consumidos por query (Groq y Gemini lo devuelven en el response). Calcular costo proyectado mensual aunque hoy sea $0. Esa tabla en el dashboard demuestra que pensaste como dueño de la app.