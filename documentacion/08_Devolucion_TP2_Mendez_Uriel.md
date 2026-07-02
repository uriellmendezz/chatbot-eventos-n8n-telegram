**Devolución TP2 - n8n Versatilidad y Dashboard**

**Alumno: Méndez, Uriel Emiliano**

_Materia: Aprendizaje Automático 4 - IES 21 · Revisión 22/06/2026_

| **RESULTADO TP2** | **CUMPLE COMPLETO** |
| ----------------- | ------------------- |

**Resumen ejecutivo**

El Chatbot v3 cumple los dos ejes del TP2 con un nivel técnico por encima del promedio de la cohorte. La versatilidad está implementada con detección de intent multi-dimensional (categoría + fecha + zona) y repregunta para casos ambiguos. La capa de métricas está completa: tabla queries_log en Supabase con cuatro estados distintos de log (Comando, Repregunta, Error LLM, Respuesta) y dashboard visible y accesible en GitHub Pages.

**Cumplimiento de la consigna**

| **Eje / Criterio**                          | **Estado**   | **Observación**                                                                                                                                            |
| ------------------------------------------- | ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Eje 1 - Versatilidad (intent detection)** | **✓ Cumple** | Categorías (shows/electrónica/cultura/gastronomía/deportes) + fecha (hoy/finde/semana) + zona. IF Intent Claro repregunta si falta info.                   |
| **Eje 2 - Tabla queries_log**               | **✓ Cumple** | 4 nodos Supabase de log por estado: Comando, Repregunta, Error LLM, Respuesta. Campos: chat_id, ts, mensaje_raw, comando, intent, resultado, etc.          |
| **Eje 2 - Dashboard visible**               | **✓ Cumple** | <https://uriellmendezz.github.io/dashboard-n8n-propio/> - HTML + supabase-js + Chart.js en GitHub Pages.                                                   |
| **Stack mínimo**                            | **✓ Cumple** | Schedule Trigger + Telegram Trigger + 9 HTTP + 16 Code + 5 IF + Telegram out con parse_mode HTML.                                                          |
| **Fase 4 - Robustez**                       | **✓ Cumple** | 9 nodos con retry. 5 IF de validación (Hay Eventos, Mensaje Válido, Es Comando Especial, Intent Claro, Respuesta LLM Válida). Defensa en profundidad real. |
| **Sin hardcodes**                           | **✓ Cumple** | Apify, Groq, Supabase y Telegram todos en credentials. Variables de entorno usadas correctamente.                                                          |
| **Continuidad del TP1**                     | **✓ Cumple** | Mantiene el pipeline paralelo en 3 ramas (RSS/HTML/XHR) del v2 con extractores LLM separados.                                                              |

**Lo que hiciste bien (técnica destacada)**

- **Logging granular por estado del flujo.** Cuatro nodos distintos de log a queries_log según qué pasó: Comando ejecutado, Repregunta enviada al usuario, Error del LLM detectado, Respuesta válida entregada. Esto es nivel de producción - el dashboard puede mostrar no solo "queries totales" sino la distribución por estado y detectar dónde se rompe el funnel.
- **Repregunta como nodo explícito (IF Intent Claro).** Convertir la repregunta en un IF separado del intent classifier es la decisión correcta: hace que el comportamiento sea predecible y testeable. Mucho mejor que dejarlo implícito en el prompt del agente.
- **Agente "Colo" con SupabaseTool + system prompt acotado.** El system prompt define categorías taxativas, regla anti-alucinación ("Prohibido inventar eventos o links"), formato estricto de salida (Telegram Markdown con hipervínculos). La estrategia "el agente pide todos los eventos y filtra él según el contexto de búsqueda detectado" es elegante porque deja la lógica de filtrado en el LLM y mantiene la consulta a Supabase simple.
- **Pipeline paralelo en 3 ramas (RSS / HTML estático / XHR).** Mantener la separación por tipo de fuente con extractores LLM especializados es decisión arquitectural de senior. La rama A para RSS estructurado, B para HTML con cheerio, C para sitios JS-heavy con delay antibloqueo y headers personalizados.
- **Cero secretos hardcodeados.** Apify, Groq y Supabase todos en credentials. Variables de entorno para la URL de Supabase. Esto es la práctica de seguridad más importante y la cumplís a fondo.
- **Dashboard real en infraestructura gratuita.** GitHub Pages para el frontend + Supabase free para el backend. Sin tarjeta de crédito, sin servidores propios, pero con HTML cliente + Chart.js consultando Postgres en tiempo real. Es exactamente el caso de uso que la consigna pedía.
- **Esquema enriquecido en Supabase.** fecha_iso ISO 8601 para queries SQL nativas + fuente_tipo para auditar origen del tráfico. Pensar el schema antes de poblarlo es lo que diferencia un MVP de un prototipo.

**Detalles menores a revisar antes de la evaluación**

- El workflow está marcado como active=false en el JSON entregado. Acordate de activarlo en n8n antes de que el docente lo pruebe (botón Active arriba a la derecha). Si lo desactivaste para ahorrar créditos durante la espera, está bien - pero asegurate de prenderlo en el momento de evaluación.
- No usás \$getWorkflowStaticData en ningún punto. Como ya tenés Supabase para persistencia formal, no es un problema, pero como cache rápida intra-corrida (por ejemplo, evitar repetir el extractor LLM en eventos ya procesados durante la misma ejecución del scheduler) puede sumar performance.

**Oportunidades de profundización (todo gratis, opcional)**

- **Bonus +0.3 - Comando admin /metrics.** Si el chat_id del mensaje coincide con el tuyo (hardcoded como variable de entorno), devolvés los KPIs del dashboard como texto formateado por Telegram. Útil para revisar uptime y estado desde el celular sin abrir el dashboard. ~15 minutos.
- **Bonus +0.3 - A/B testing de system prompts.** Tener dos versiones del system message de Colo (A y B). En cada interacción, elegir A o B al azar (50/50). Loguear en queries_log la versión usada. Después de N queries, comparar tasa de "el usuario volvió a preguntar" como proxy de calidad. Si una versión gana claramente, dejás esa. ~30 minutos.
- **Bonus +0.3 - Recomendación proactiva.** Agregar una tabla user_preferences (chat_id, categorias_favoritas, zona). Un Schedule semanal que recorre la tabla, busca eventos del finde que coincidan con cada usuario y se los manda proactivamente. Tu infra Supabase ya lo permite. ~45 minutos.
- **Row Level Security (RLS) en Supabase.** Aunque el dashboard cliente use anon key, conviene activar RLS en queries_log y eventos para que un token comprometido no pueda borrar o modificar filas. Policy de SELECT pública en views agregadas + writes solo desde service_role del backend. ~20 minutos.
- **Trace IDs end-to-end.** Generar un UUID al inicio de cada interacción (en el Telegram Trigger o el primer Code) y propagarlo a los 4 nodos de log + a los logs internos. Permite depurar "esta respuesta salió rara" rastreando todo el funnel desde el dashboard. ~15 minutos.
- **Backup del workflow en GitHub privado.** Cada cambio significativo, exportá el JSON y commiteá. Si tu Hugging Face Space se reinicia o se corrompe, recuperás en 2 minutos. Como ya tenés cuenta de GitHub (por el dashboard), es un repo más.
- **Schema versioning del scraper.** En cada rama (A/B/C) sumar un Code node que cuente eventos extraídos. Si la cuenta cae bajo un umbral mínimo (ej: < 5 en una corrida), log nivel ERROR en queries_log y alerta por Telegram al admin. Detecta cambios en el HTML del sitio fuente antes de que el dashboard se vacíe.

**Mirada hacia un producto comercial**

Lo que entregaste es nivel MVP listo para mostrar. El stack es 100% gratuito (Hugging Face Space + Supabase free + GitHub Pages + Groq) y la arquitectura escala con cambios mínimos a la versión paga si crece el uso. Eso es ingeniería de producto, no proyecto de cursada.

Para llevarlo al siguiente nivel, sin gastar plata: pensar la métrica más importante del dueño de la app. Hoy el dashboard muestra "uso" - pero el dueño quiere saber "¿qué usuarios vuelven?", "¿qué intent no responde bien?", "¿qué categoría es la más demandada que NO tengo bien cubierta?". Esas son preguntas que se responden con vistas SQL armadas con cuidado sobre queries_log + eventos. Diseñar 3-4 de esas vistas vale más que 10 gráficos genéricos.

Tu separación entre log de Comando / Repregunta / Error / Respuesta es exactamente lo que permite armar un funnel: "entraron 100, 20 fueron repregunta porque el intent no era claro, 5 fallaron por error LLM, 75 obtuvieron respuesta". Ese funnel en el dashboard es la métrica más valiosa que puede tener el dueño y vos ya tenés la data cruda para construirlo.

**Cierre**

Excelente trabajo de TP2. El bot pasó de "funcional" en el TP1 a "consumible por un dueño de app" en el TP2. Cumple los dos ejes a fondo, el stack es 100% gratuito y la calidad técnica está por encima de lo pedido. Si sumás dos o tres bonus de los listados, no solo cierra el TP2 sino que tenés material para portfolio profesional.