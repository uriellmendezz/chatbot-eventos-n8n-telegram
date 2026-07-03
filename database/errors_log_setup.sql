-- ============================================================
-- INTEGRADOR: Tabla errors_log + KPI Views
-- Ejecutar en el SQL Editor de Supabase (app.supabase.com)
-- ============================================================

-- ============================================================
-- 1. TABLA: errors_log
-- Recibe registros de los 3 mecanismos:
--   - Mecanismo 1: Error Trigger (workflow crashes)
--   - Mecanismo 2: Validación post-LLM (respuesta vacía/corta)
--   - Mecanismo 3: Schema versioning (scraper con pocos resultados)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.errors_log (
    id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    ts          TIMESTAMPTZ DEFAULT NOW(),       -- Timestamp ISO del error
    level       TEXT        NOT NULL             -- 'INFO' | 'WARN' | 'ERROR'
                CHECK (level IN ('INFO', 'WARN', 'ERROR')),
    workflow    TEXT,                            -- Nombre del workflow donde ocurrió
    nodo        TEXT,                            -- Nombre del nodo donde ocurrió
    tipo        TEXT,                            -- 'workflow_error' | 'llm_respuesta_invalida' | 'schema_change_sospechoso'
    mensaje     TEXT,                            -- Descripción corta del error
    detalle     TEXT                             -- Datos adicionales (sin credentials)
);

-- ============================================================
-- 2. ÍNDICES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_errors_log_ts
    ON public.errors_log(ts DESC);

CREATE INDEX IF NOT EXISTS idx_errors_log_level
    ON public.errors_log(level);

CREATE INDEX IF NOT EXISTS idx_errors_log_tipo
    ON public.errors_log(tipo);

CREATE INDEX IF NOT EXISTS idx_errors_log_ts_day
    ON public.errors_log(DATE_TRUNC('day', ts));

-- ============================================================
-- 3. ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE public.errors_log ENABLE ROW LEVEL SECURITY;

-- El service_role (n8n) puede escribir: bypasea RLS automáticamente
-- El anon role puede leer solo las VISTAS AGREGADAS (no datos crudos)

-- ============================================================
-- 4. KPI VIEW: Tasa de errores últimas 24 horas
-- KPI principal: errores recientes para detectar si algo está roto AHORA
-- ============================================================
CREATE OR REPLACE VIEW public.kpi_errores_24h AS
    SELECT
        COUNT(*) AS total_errores_24h,
        SUM(CASE WHEN level = 'ERROR' THEN 1 ELSE 0 END) AS errores_criticos,
        SUM(CASE WHEN level = 'WARN'  THEN 1 ELSE 0 END) AS advertencias,
        (
            SELECT COUNT(*)
            FROM public.queries_log
            WHERE ts >= NOW() - INTERVAL '24 hours'
              AND es_comando = false
        ) AS total_interacciones_24h,
        ROUND(
            COUNT(*) * 100.0 / NULLIF(
                (SELECT COUNT(*) FROM public.queries_log
                 WHERE ts >= NOW() - INTERVAL '24 hours' AND es_comando = false),
                0
            ), 2
        ) AS tasa_errores_pct
    FROM public.errors_log
    WHERE ts >= NOW() - INTERVAL '24 hours';

-- ============================================================
-- 5. KPI VIEW: Tipo de error más frecuente
-- ============================================================
CREATE OR REPLACE VIEW public.kpi_errores_por_tipo AS
    SELECT
        COALESCE(tipo, 'desconocido') AS tipo,
        level,
        COUNT(*) AS total,
        MAX(ts)  AS ultimo_ocurrido
    FROM public.errors_log
    GROUP BY tipo, level
    ORDER BY total DESC;

-- ============================================================
-- 6. KPI VIEW: Línea de tiempo de errores por día
-- Para gráfico de barras en el dashboard
-- ============================================================
CREATE OR REPLACE VIEW public.kpi_errores_por_dia AS
    SELECT
        DATE_TRUNC('day', ts)::DATE AS dia,
        COUNT(*) AS total_errores,
        SUM(CASE WHEN level = 'ERROR' THEN 1 ELSE 0 END) AS errores_criticos,
        SUM(CASE WHEN level = 'WARN'  THEN 1 ELSE 0 END) AS advertencias,
        SUM(CASE WHEN tipo = 'schema_change_sospechoso' THEN 1 ELSE 0 END) AS schema_warnings,
        SUM(CASE WHEN tipo = 'llm_respuesta_invalida'   THEN 1 ELSE 0 END) AS llm_errors,
        SUM(CASE WHEN tipo = 'workflow_error'           THEN 1 ELSE 0 END) AS workflow_crashes
    FROM public.errors_log
    GROUP BY 1
    ORDER BY 1 DESC;

-- ============================================================
-- 7. KPI VIEW: Fuente/nodo con más errores
-- ============================================================
CREATE OR REPLACE VIEW public.kpi_errores_por_nodo AS
    SELECT
        COALESCE(nodo, 'desconocido') AS nodo,
        COALESCE(workflow, 'desconocido') AS workflow,
        COUNT(*) AS total_errores,
        MAX(ts)  AS ultimo_ocurrido
    FROM public.errors_log
    GROUP BY nodo, workflow
    ORDER BY total_errores DESC;

-- ============================================================
-- 8. GRANTS: anon puede leer solo las vistas (no la tabla cruda)
-- ============================================================
GRANT SELECT ON public.kpi_errores_24h       TO anon;
GRANT SELECT ON public.kpi_errores_por_tipo  TO anon;
GRANT SELECT ON public.kpi_errores_por_dia   TO anon;
GRANT SELECT ON public.kpi_errores_por_nodo  TO anon;

-- ============================================================
-- 9. VERIFICACIÓN
-- ============================================================
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'errors_log'
ORDER BY ordinal_position;
