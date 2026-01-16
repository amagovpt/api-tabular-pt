CREATE TABLE IF NOT EXISTS public.datasets (
    id SERIAL PRIMARY KEY,
    dataset_id VARCHAR(50),
    metric_month DATE,
    visit_count INTEGER DEFAULT 0,
    download_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.downloads (
    id SERIAL PRIMARY KEY,
    dataset_id VARCHAR(50),
    resource_id VARCHAR(50),
    user_id VARCHAR(50),
    date DATE DEFAULT CURRENT_DATE
);
CREATE TABLE IF NOT EXISTS public.views (
    id SERIAL PRIMARY KEY,
    dataset_id VARCHAR(50),
    resource_id VARCHAR(50),
    user_id VARCHAR(50),
    date DATE DEFAULT CURRENT_DATE
);
CREATE TABLE IF NOT EXISTS public.site (
    id SERIAL PRIMARY KEY,
    metric_month DATE,
    visit_count INTEGER DEFAULT 0,
    download_count INTEGER DEFAULT 0,
    dataset_count INTEGER DEFAULT 0,
    reuse_count INTEGER DEFAULT 0,
    organization_count INTEGER DEFAULT 0,
    user_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);


-- 3. (Opcional) Índices para melhorar a performance
CREATE INDEX IF NOT EXISTS idx_views_dataset ON public.views (dataset_id);
CREATE INDEX IF NOT EXISTS idx_downloads_dataset ON public.downloads (dataset_id);
CREATE INDEX IF NOT EXISTS idx_datasets_dataset_id ON public.datasets (dataset_id);
CREATE INDEX IF NOT EXISTS idx_site_metric_month ON public.site (metric_month);

-- 4. Garantir permissões (ajuste 'postgres' se o seu PostgREST usar outro user)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.views TO postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.downloads TO postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.datasets TO postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.site TO postgres;
GRANT USAGE, SELECT ON SEQUENCE public.views_id_seq TO postgres;
GRANT USAGE, SELECT ON SEQUENCE public.downloads_id_seq TO postgres;
GRANT USAGE, SELECT ON SEQUENCE public.datasets_id_seq TO postgres;
GRANT USAGE, SELECT ON SEQUENCE public.site_id_seq TO postgres;


