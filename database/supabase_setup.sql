-- ============================================================
-- SUPABASE SETUP: Ecosistema n8n Multi-Scraper - Córdoba Eventos
-- ============================================================
-- Ejecutar en el SQL Editor de Supabase (app.supabase.com)
-- ============================================================

-- 1. CREAR EXTENSIÓN PARA UUID (ya viene activada en Supabase por defecto)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 2. TABLA PRINCIPAL: eventos
-- ============================================================
CREATE TABLE IF NOT EXISTS public.eventos (
    -- Identificador único interno
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Datos del evento (schema unificado del Code Node de Estandarización)
    titulo          TEXT        NOT NULL,
    fecha_original  TEXT,                           -- Texto libre tal como lo devuelve la fuente
    fecha_iso       TIMESTAMPTZ,                    -- Fecha parseada a ISO 8601 (para filtros)
    categoria       TEXT        NOT NULL,           -- 'shows' | 'electronica' | 'cultura' | 'gastronomia' | 'deportes'
    ubicacion       TEXT,
    link            TEXT        NOT NULL UNIQUE,    -- CLAVE ÚNICA para UPSERT y deduplicación
    fuente          TEXT        NOT NULL,           -- Nombre del sitio de origen (ej: 'CBA Beat', 'Eden Entradas')
    descripcion     TEXT,                           -- Descripción breve o extracto

    -- Metadata de scraping
    scraped_at      TIMESTAMPTZ DEFAULT NOW(),      -- Cuándo fue ingresado/actualizado
    fuente_tipo     TEXT        DEFAULT 'http'      -- 'rss' | 'html' | 'xhr' | 'apify'
);

-- ============================================================
-- 3. ÍNDICES PARA OPTIMIZAR BÚSQUEDAS DEL AI AGENT
-- ============================================================

-- Índice en categoria (filtro más frecuente del agente)
CREATE INDEX IF NOT EXISTS idx_eventos_categoria
    ON public.eventos(categoria);

-- Índice en fecha_iso (para filtrar eventos futuros y rangos de fecha)
CREATE INDEX IF NOT EXISTS idx_eventos_fecha_iso
    ON public.eventos(fecha_iso);

-- Índice compuesto: categoria + fecha_iso (la query más común del agente)
CREATE INDEX IF NOT EXISTS idx_eventos_cat_fecha
    ON public.eventos(categoria, fecha_iso);

-- Índice en fuente (útil para depuración y reportes por fuente)
CREATE INDEX IF NOT EXISTS idx_eventos_fuente
    ON public.eventos(fuente);

-- Índice en scraped_at (para el mantenimiento automático)
CREATE INDEX IF NOT EXISTS idx_eventos_scraped_at
    ON public.eventos(scraped_at);

-- ============================================================
-- 4. HABILITAR ROW LEVEL SECURITY (RLS)
-- ============================================================
-- Recomendado para Supabase: la service_role key bypasea RLS,
-- pero la anon key necesita policies explícitas.

ALTER TABLE public.eventos ENABLE ROW LEVEL SECURITY;

-- Policy de solo lectura para anon (el AI Agent puede leer)
CREATE POLICY "Lectura pública de eventos"
    ON public.eventos
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- Policy de escritura solo para service_role (el workflow ETL escribe)
-- La service_role key bypasea RLS automáticamente, no necesita policy.

-- ============================================================
-- 5. FUNCIÓN DE LIMPIEZA AUTOMÁTICA (llamada desde n8n)
-- ============================================================
-- n8n ejecuta esta función RPC al final del proceso ETL
-- para eliminar eventos con fecha_iso anterior a hoy.

CREATE OR REPLACE FUNCTION public.limpiar_eventos_pasados()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    eliminados INTEGER;
BEGIN
    DELETE FROM public.eventos
    WHERE fecha_iso < NOW();

    GET DIAGNOSTICS eliminados = ROW_COUNT;
    RETURN eliminados;
END;
$$;

-- ============================================================
-- 6. FUNCIÓN UPSERT CUSTOMIZADA (alternativa al upsert nativo)
-- ============================================================
-- Para usar desde n8n con el nodo Supabase (operación upsert por 'link')
-- n8n puede hacer upsert directamente con ON CONFLICT(link) DO UPDATE.

-- Ejemplo de query manual que n8n puede ejecutar vía nodo "Execute Query":
-- INSERT INTO eventos (titulo, fecha_original, fecha_iso, categoria, ubicacion, link, fuente, descripcion, fuente_tipo)
-- VALUES (...)
-- ON CONFLICT (link) DO UPDATE SET
--     titulo         = EXCLUDED.titulo,
--     fecha_original = EXCLUDED.fecha_original,
--     fecha_iso      = EXCLUDED.fecha_iso,
--     ubicacion      = EXCLUDED.ubicacion,
--     descripcion    = EXCLUDED.descripcion,
--     scraped_at     = NOW();

-- ============================================================
-- 7. VISTA ÚTIL: Eventos futuros para el AI Agent
-- ============================================================
CREATE OR REPLACE VIEW public.eventos_futuros AS
    SELECT
        id,
        titulo,
        fecha_original,
        fecha_iso,
        categoria,
        ubicacion,
        link,
        fuente,
        descripcion
    FROM public.eventos
    WHERE fecha_iso >= NOW()
    ORDER BY fecha_iso ASC;

-- Policy de lectura en la vista
CREATE POLICY "Lectura pública eventos futuros"
    ON public.eventos
    FOR SELECT
    TO anon, authenticated
    USING (fecha_iso >= NOW());

-- ============================================================
-- 8. TABLA DE LOGS: queries_log (TP2 — Métricas del dashboard)
-- ============================================================
-- Cada interacción del usuario con el bot inserta una fila aquí.
-- Alimentada desde el nodo "Supabase: Log Query" en n8n.

CREATE TABLE IF NOT EXISTS public.queries_log (
    id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    ts                  TIMESTAMPTZ DEFAULT NOW(),           -- Timestamp exacto de la interacción
    chat_id             TEXT        NOT NULL,                -- ID de Telegram (NO nombre/apellido)
    mensaje_raw         TEXT,                               -- Texto original del usuario (sin PII)
    intent_categoria    TEXT,                               -- 'shows' | 'electronica' | 'cultura' | 'gastronomia' | 'deportes' | null
    intent_fecha        TEXT,                               -- 'hoy' | 'finde' | 'semana' | 'puntual' | null
    intent_zona         TEXT,                               -- zona geográfica detectada o null
    intent_ambiguo      BOOLEAN     DEFAULT false,          -- true si el bot tuvo que repreguntar
    eventos_devueltos   INT         DEFAULT 0,              -- Cuántos eventos se enviaron al usuario
    latencia_ms         INT,                                -- Latencia total de respuesta en ms
    fuente_resuelta     TEXT,                               -- Fuente principal de los eventos respondidos
    resultado_count     INT         DEFAULT 0,              -- Alias de eventos_devueltos (compatibilidad)
    tokens_in           INT,                                -- Tokens de entrada al LLM (si disponible)
    tokens_out          INT,                                -- Tokens de salida del LLM (si disponible)
    es_comando          BOOLEAN     DEFAULT false,          -- true si fue /start /help /metrics
    comando             TEXT                                -- '/start' | '/help' | '/metrics' | null
);

-- Índices para las queries del dashboard
CREATE INDEX IF NOT EXISTS idx_qlog_ts
    ON public.queries_log(ts DESC);

CREATE INDEX IF NOT EXISTS idx_qlog_chat_id
    ON public.queries_log(chat_id);

CREATE INDEX IF NOT EXISTS idx_qlog_intent_cat
    ON public.queries_log(intent_categoria);

CREATE INDEX IF NOT EXISTS idx_qlog_ts_day
    ON public.queries_log(DATE_TRUNC('day', ts));

-- RLS: Habilitar Row Level Security
ALTER TABLE public.queries_log ENABLE ROW LEVEL SECURITY;

-- El service_role (n8n ETL) puede escribir: no necesita policy (bypasea RLS)
-- El anon role NO puede leer la tabla cruda (protege datos de usuarios)
-- Solo puede leer las VISTAS AGREGADAS definidas abajo.

-- ============================================================
-- 9. VISTAS AGREGADAS PARA EL DASHBOARD (anon-safe)
-- ============================================================
-- Estas vistas NO exponen datos individuales de usuarios.
-- El dashboard las consulta con la anon key de Supabase (sin riesgo).

-- KPI 1: Queries por día
CREATE OR REPLACE VIEW public.kpi_queries_por_dia AS
    SELECT
        DATE_TRUNC('day', ts)::DATE AS dia,
        COUNT(*)                    AS total_queries,
        COUNT(DISTINCT chat_id)     AS usuarios_unicos
    FROM public.queries_log
    WHERE es_comando = false  -- Excluir /start /help /metrics del conteo
    GROUP BY 1
    ORDER BY 1 DESC;

-- KPI 2: Top de intenciones por categoría
CREATE OR REPLACE VIEW public.kpi_top_categorias AS
    SELECT
        COALESCE(intent_categoria, 'sin_categoria') AS categoria,
        COUNT(*)                                    AS total,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS porcentaje
    FROM public.queries_log
    WHERE es_comando = false
    GROUP BY 1
    ORDER BY 2 DESC;

-- KPI 3: Tasa de respuestas con resultados vs vacías
CREATE OR REPLACE VIEW public.kpi_tasa_resultados AS
    SELECT
        SUM(CASE WHEN eventos_devueltos > 0 THEN 1 ELSE 0 END)  AS con_resultados,
        SUM(CASE WHEN eventos_devueltos = 0 THEN 1 ELSE 0 END)  AS sin_resultados,
        COUNT(*)                                                  AS total,
        ROUND(
            SUM(CASE WHEN eventos_devueltos > 0 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0),
            1
        )                                                         AS tasa_exito_pct
    FROM public.queries_log
    WHERE es_comando = false;

-- KPI 4: Latencia promedio por día
CREATE OR REPLACE VIEW public.kpi_latencia AS
    SELECT
        DATE_TRUNC('day', ts)::DATE AS dia,
        ROUND(AVG(latencia_ms))     AS latencia_promedio_ms,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY latencia_ms)) AS latencia_p50_ms,
        ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY latencia_ms)) AS latencia_p95_ms
    FROM public.queries_log
    WHERE latencia_ms IS NOT NULL
      AND es_comando = false
    GROUP BY 1
    ORDER BY 1 DESC;

-- KPI 5: Fuentes que más eventos resuelven
CREATE OR REPLACE VIEW public.kpi_fuentes AS
    SELECT
        COALESCE(fuente_resuelta, 'desconocida') AS fuente,
        COUNT(*)                                  AS apariciones,
        SUM(eventos_devueltos)                    AS total_eventos_resueltos
    FROM public.queries_log
    WHERE fuente_resuelta IS NOT NULL
      AND es_comando = false
    GROUP BY 1
    ORDER BY 3 DESC;

-- KPI 6: Resumen general (single-row para el header del dashboard)
CREATE OR REPLACE VIEW public.kpi_resumen AS
    SELECT
        COUNT(*)                                AS total_queries,
        COUNT(DISTINCT chat_id)                 AS usuarios_unicos_total,
        ROUND(AVG(latencia_ms))                 AS latencia_promedio_ms,
        ROUND(
            SUM(CASE WHEN eventos_devueltos > 0 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0),
            1
        )                                       AS tasa_exito_pct,
        SUM(CASE WHEN intent_ambiguo THEN 1 ELSE 0 END) AS total_repregunas
    FROM public.queries_log
    WHERE es_comando = false;

-- Policy: anon solo puede leer las VISTAS (no la tabla cruda)
-- Las vistas heredan los permisos de la tabla. Necesitamos GRANT explícito.
GRANT SELECT ON public.kpi_queries_por_dia  TO anon;
GRANT SELECT ON public.kpi_top_categorias   TO anon;
GRANT SELECT ON public.kpi_tasa_resultados  TO anon;
GRANT SELECT ON public.kpi_latencia         TO anon;
GRANT SELECT ON public.kpi_fuentes          TO anon;
GRANT SELECT ON public.kpi_resumen          TO anon;

-- ============================================================
-- 10. VERIFICACIÓN: Ver estructura creada
-- ============================================================
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'eventos'
ORDER BY ordinal_position;

-- Ver tablas creadas
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
