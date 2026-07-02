-- ============================================================
-- TP2 SETUP — Solo las partes NUEVAS (seguro re-ejecutar)
-- NO modifica la tabla "eventos" ni sus policies existentes.
-- Ejecutar en: Supabase → SQL Editor
-- ============================================================

-- ============================================================
-- 1. TABLA DE LOGS: queries_log
-- ============================================================
CREATE TABLE IF NOT EXISTS public.queries_log (
    id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    ts                  TIMESTAMPTZ DEFAULT NOW(),
    chat_id             TEXT        NOT NULL,
    mensaje_raw         TEXT,
    intent_categoria    TEXT,
    intent_fecha        TEXT,
    intent_zona         TEXT,
    intent_ambiguo      BOOLEAN     DEFAULT false,
    eventos_devueltos   INT         DEFAULT 0,
    latencia_ms         INT,
    fuente_resuelta     TEXT,
    resultado_count     INT         DEFAULT 0,
    tokens_in           INT,
    tokens_out          INT,
    es_comando          BOOLEAN     DEFAULT false,
    comando             TEXT
);

-- ============================================================
-- 2. ÍNDICES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_qlog_ts
    ON public.queries_log(ts DESC);

CREATE INDEX IF NOT EXISTS idx_qlog_chat_id
    ON public.queries_log(chat_id);

CREATE INDEX IF NOT EXISTS idx_qlog_intent_cat
    ON public.queries_log(intent_categoria);

-- NOTA: No se crea índice sobre DATE_TRUNC(ts) porque TIMESTAMPTZ
-- no es IMMUTABLE con DATE_TRUNC. El índice en ts DESC ya cubre
-- las queries por rango de fecha del dashboard.


-- ============================================================
-- 3. RLS EN queries_log
-- ============================================================
ALTER TABLE public.queries_log ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 4. VISTAS KPI PARA EL DASHBOARD (anon-safe)
-- ============================================================

-- KPI 1: Queries por día
CREATE OR REPLACE VIEW public.kpi_queries_por_dia AS
    SELECT
        DATE_TRUNC('day', ts)::DATE AS dia,
        COUNT(*)                    AS total_queries,
        COUNT(DISTINCT chat_id)     AS usuarios_unicos
    FROM public.queries_log
    WHERE es_comando = false
    GROUP BY 1
    ORDER BY 1 DESC;

-- KPI 2: Top categorías
CREATE OR REPLACE VIEW public.kpi_top_categorias AS
    SELECT
        COALESCE(intent_categoria, 'sin_categoria') AS categoria,
        COUNT(*)                                    AS total,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS porcentaje
    FROM public.queries_log
    WHERE es_comando = false
    GROUP BY 1
    ORDER BY 2 DESC;

-- KPI 3: Tasa de resultados vs vacías
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

-- KPI 4: Latencia por día
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

-- ============================================================
-- 5. GRANTS PARA ANON (el dashboard puede leer las vistas)
-- ============================================================
GRANT SELECT ON public.kpi_queries_por_dia  TO anon;
GRANT SELECT ON public.kpi_top_categorias   TO anon;
GRANT SELECT ON public.kpi_tasa_resultados  TO anon;
GRANT SELECT ON public.kpi_latencia         TO anon;
GRANT SELECT ON public.kpi_fuentes          TO anon;
GRANT SELECT ON public.kpi_resumen          TO anon;

-- ============================================================
-- 6. VERIFICACIÓN FINAL
-- ============================================================
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_type, table_name;
