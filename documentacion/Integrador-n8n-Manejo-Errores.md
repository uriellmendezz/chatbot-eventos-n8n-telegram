**TRABAJO INTEGRADOR - APRENDIZAJE AUTOMÁTICO 4**

**Manejo de errores y resiliencia del bot**

_Cierre del cuatrimestre: que el bot avise cuando algo se rompe_

**Fecha límite de presentación: viernes 04/07/2026**

_Tienen 4 días desde hoy. Enviar por mail a lgiannasi@ies21.edu.ar_

**Lean esto antes de empezar**

El integrador está pensado para que todos lleguen al mismo nivel técnico al cierre del cuatrimestre. El alcance está acotado a propósito a cuatro mecanismos concretos sobre el flujo que ya tienen del TP2. No hay que rehacer nada, se suman capas encima.

El plazo es corto (4 días) y los mecanismos están diseñados para resolverse en una tarde de trabajo concentrado (alrededor de 2 horas en total si tu TP2 está cerrado). Si el TP2 todavía no está cerrado, el integrador funciona como excusa para cerrarlo: lo que se les pide se monta encima del flujo principal.

**Contexto**

A lo largo del cuatrimestre construyeron un bot que scrapea fuentes, las cura con un LLM y responde por Telegram (TP1), y le sumaron versatilidad y dashboard (TP2). Hoy los bots responden cuando todo va bien. Cuando algo se rompe (una fuente cae, el LLM devuelve cualquier cosa, una API rechaza el request), el flujo muere en silencio y el usuario queda esperando una respuesta que no llega.

La diferencia entre un prototipo y un sistema de producción es cómo se comporta cuando algo falla. En este integrador van a sumar esa pieza.

**La tarea - cuatro mecanismos obligatorios**

**1\. Error Trigger workflow secundario**

Un segundo workflow en n8n que escucha errores del workflow principal y avisa al admin por Telegram. n8n lo soporta nativamente con el nodo Error Trigger.

**Cómo se hace (5 minutos):** New workflow → primer nodo Error Trigger → segundo nodo Telegram con text: '⚠️ Error en {{ \$json.workflow.name }} - nodo: {{ \$json.execution.error.node.name }} - mensaje: {{ \$json.execution.error.message }}'. En el workflow principal: Settings → Error Workflow → seleccionar este. Listo.

**2\. Validación post-LLM con rama de fallback**

Un IF después del nodo del LLM (o del AI Agent) que verifique que la respuesta no esté vacía y tenga el formato esperado. Si falla, mensaje al usuario + log del error.

**Condiciones mínimas del IF:**

- {{ \$json.output }} no es vacío ni undefined.
- Longitud mayor a 20 caracteres (descarta "no sé", "ok", etc.).
- Si esperás formato fijo (ej. contiene "🎉" o "Evento:"), test específico.

Rama FALSE → mensaje al usuario: "Tuve un problema procesando tu pedido, probá de nuevo en un rato" + insert en errors_log con el dato crudo del LLM.

**3\. Schema versioning del scraper**

Code node después del scraping que cuenta cuántos elementos encontró. Si la cuenta cae bajo un umbral (ej. menos de 5 eventos), se registra como advertencia y se dispara una alerta. Sirve para detectar cambios en el HTML de la fuente ANTES de que el dashboard se vacíe.

**Código sugerido para copiar al Code node:**

const items = \$input.all();  
const cantidad = items.length;  
const fuente = items\[0\]?.json?.fuente || 'desconocida';  
if (cantidad < 5) {  
return \[{ json: {  
level: 'WARN',  
tipo: 'schema_change_sospechoso',  
fuente,  
cantidad,  
ts: new Date().toISOString()  
} }\];  
}  
return items;

**4\. Tabla errors_log + KPI nuevo en el dashboard**

Una tabla nueva (en el mismo Sheets o Supabase del TP2) donde se registran TODOS los errores detectados por los mecanismos 1, 2 y 3. El dashboard del TP2 suma al menos un KPI basado en esta tabla.

**Esquema mínimo:** ts (timestamp ISO), level (INFO/WARN/ERROR), workflow, nodo, tipo, mensaje, detalle.

**KPI a sumar al dashboard (al menos uno):**

- Tasa de errores últimas 24 horas (errores / interacciones totales).
- Fuente con más errores (agrupado por workflow/nodo).
- Tipo de error más frecuente.
- Línea de tiempo de errores por día (gráfico de barras).

**Regla de costo cero**

Todo lo que pide este integrador se resuelve con herramientas gratuitas. La institución no provee herramientas pagas y no están obligados a usar herramientas que requieran tarjeta de crédito.

| **Necesidad**                 | **Herramienta gratis**                                                  |
| ----------------------------- | ----------------------------------------------------------------------- |
| Error Trigger workflow        | n8n self-hosted (Docker, Oracle Cloud, Hugging Face Space, Render free) |
| Tabla errors_log              | Google Sheets (misma del TP2) o Supabase free tier                      |
| Dashboard con KPI nuevo       | Looker Studio gratis sobre Sheets, Supabase Studio o GitHub Pages       |
| Alertas por Telegram al admin | Bot API de Telegram (gratis, sin límites)                               |

**Plan sugerido para los 4 días**

Distribución realista. Si lo arrancan el lunes a la noche, pueden tenerlo cerrado el jueves con margen para el viernes de margen.

**Día 1 (martes) - Base de logging (45 minutos)**

- Crear tabla errors_log con el esquema (ts, level, workflow, nodo, tipo, mensaje, detalle).
- Insertar manualmente una fila de prueba para confirmar que se puede escribir.
- Crear el workflow nuevo del Error Trigger con el Telegram al admin.
- En el workflow principal: Settings → Error Workflow → seleccionar el nuevo.
- Forzar un error a propósito en el principal (por ejemplo, un HTTP a <https://example-broken.fake>) y verificar que llega la alerta.

**Día 2 (miércoles) - Validación y schema versioning (45 minutos)**

- IF post-LLM con las condiciones mínimas + rama de fallback con mensaje al usuario + insert en errors_log.
- Probar mandando al bot un mensaje raro que confunda al LLM. Verificar que la rama de fallback se dispara.
- Code node después del scraping con el snippet de schema versioning. Configurar el umbral mínimo (ej. 5).
- Probar bajando temporalmente el umbral a 999 (forzar el caso "pocos resultados") y verificar que loguea.

**Día 3 (jueves) - Dashboard y testing integrado (60 minutos)**

- Sumar el KPI nuevo al dashboard. Si usás Looker Studio, una pestaña nueva "Salud del sistema" con el gráfico elegido.
- Si tu dashboard es HTML + Chart.js, agregar un canvas con la query a errors_log.
- Hacer pruebas reales: mandar 5-10 mensajes al bot (algunos válidos, algunos raros) y ver que los logs aparecen y que el dashboard refleja lo que pasó.
- Capturar el GIF/captura del Error Trigger en acción para el entregable.

**Día 4 (viernes) - Informe y entrega (30-45 minutos)**

- Escribir el informe corto (1-2 páginas). Estructura sugerida abajo.
- Exportar el JSON del workflow principal y del Error Trigger desde n8n.
- Armar el mail con: JSON, link al dashboard, esquema de errors_log, informe y captura.
- Enviar antes del cierre del viernes.

**Consulta intermedia abierta**

Miércoles 02/07 en horario de clase, estoy disponible por mail/WhatsApp para responder dudas de quien ya esté armando el integrador. Aprovéchenlo: detectar un problema el miércoles se arregla rápido; detectarlo el jueves a la noche, no.

**Entregables**

- Workflow principal y Error Trigger workflow exportados en .json desde n8n.
- URL del dashboard actualizado (el mismo del TP2 con el KPI nuevo sumado).
- Esquema de la tabla errors_log (nombre, columnas, tipos).
- Informe corto (1 a 2 páginas) que explique: qué errores podían romper el flujo antes, qué errores están detectados ahora, qué pasa cuando ocurre cada tipo, qué decisión podés tomar mirando el dashboard.
- Una captura o GIF de 10 segundos mostrando el Error Trigger en acción (Telegram recibiendo la alerta).

**Rúbrica**

| **Criterio**                                                                                     | **Peso** |
| ------------------------------------------------------------------------------------------------ | -------- |
| Mecanismo 1 - Error Trigger workflow funcionando (alerta llega por Telegram al disparar)         | 20%      |
| Mecanismo 2 - Validación post-LLM con rama de fallback al usuario probada                        | 20%      |
| Mecanismo 3 - Schema versioning del scraper detectando el caso "pocos resultados"                | 20%      |
| Mecanismo 4 - Tabla errors_log alimentada por los 3 mecanismos + KPI nuevo en el dashboard       | 20%      |
| Informe corto que explica qué errores se detectan y qué decisión toma el dueño con la info nueva | 20%      |

**Bonus opcional (hasta +1 punto)**

Estos NO son necesarios para aprobar. Solo si tienen los 4 mecanismos cerrados y tiempo de sobra:

- +0.3 - Rate limiting básico: contador por chat_id en \$getWorkflowStaticData. Si un usuario supera N consultas por hora, mensaje amable y demora.
- +0.3 - Health check workflow: Schedule cada 15 minutos que pingee tu n8n y registre uptime. 3 fallos consecutivos = alerta al admin.
- +0.4 - Dead letter queue: tabla aparte para eventos que fallaron procesamiento. Workflow de reintento manual que el admin puede disparar.

**Pistas y advertencias**

- Si tu TP2 no está cerrado, esto te sirve para cerrarlo. El integrador se monta encima, no reemplaza.
- No expongan API keys. El Error Trigger no tiene que mandar el detalle completo del error si ese detalle incluye credentials. Filtrar antes de loguear.
- No spamear con alertas. Si una fuente se rompe, no querés 100 mensajes por Telegram en 10 minutos. Usar static data para limitar a 1 alerta por hora por tipo de error.
- El Error Trigger NO se dispara con errores controlados por IF de validación. Si tu IF dice "esto está mal" y manda mensaje al usuario, eso es una rama lógica, no un error del workflow. El Error Trigger se dispara con cosas que rompen el flujo (excepciones, timeouts, errores de credentials).
- Probar antes de entregar. El Error Trigger es la pieza más fácil de NO testear porque "todo funciona". Forzá un error a propósito para verificar que el aviso llega.
- El KPI nuevo en el dashboard tiene que ser útil. "Cantidad total de errores histórica" no le sirve al dueño. "Tasa de errores en las últimas 24 horas" sí, porque indica si algo está roto AHORA.
- Si llegan al miércoles a la noche sin haber arrancado el integrador, escríbanme. Es mejor avisar que no entregar.

**Recursos sugeridos**

- Error Trigger en n8n: docs.n8n.io/code/builtin/error-trigger
- Static data en n8n: docs.n8n.io/code/builtin/static-data
- Looker Studio: lookerstudio.google.com
- Supabase: supabase.com/docs
- Chart.js: chartjs.org

**Nota de cierre**

Esta es la última pieza del cuatrimestre. Cuando lleven el bot a una entrevista laboral, no les van a preguntar si funciona - eso se asume. Les van a preguntar qué pasa cuando se rompe, cómo se enteran, qué decisión toman. Con esto cierran esa respuesta con un sistema concreto que pueden mostrar funcionando.