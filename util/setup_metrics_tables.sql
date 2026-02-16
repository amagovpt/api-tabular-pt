-- Esses comandos SQL devem ser executados na base de dados que serve a API de métricas, que no seu ambiente corresponde à porta 5434.
-- Script de configuração de tabelas e views para udata-metrics
-- Este script cria as tabelas base e as views agregadas necessárias para o comando `udata job run update-metrics`
-- funcionar corretamente com a API de métricas (api-tabular-pt / PostgREST).

-- 1. Datasets
-- Tabela para armazenar métricas mensais de datasets
CREATE TABLE IF NOT EXISTS public.datasets (
    id SERIAL PRIMARY KEY,
    dataset_id VARCHAR(50),
    metric_month DATE,
    visit_count INTEGER DEFAULT 0,
    download_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- View para expor o total de visitas e downloads por dataset (requerido pelo udata-metrics)
CREATE OR REPLACE VIEW datasets_total AS
SELECT
    row_number() OVER (ORDER BY dataset_id) AS __id,
    dataset_id,
    COALESCE(SUM(visit_count), 0) AS visit,
    COALESCE(SUM(download_count), 0) AS download_resource
FROM datasets
GROUP BY dataset_id;

-- 2. Resources (baseado em Downloads)
-- Tabela para registar downloads individuais
CREATE TABLE IF NOT EXISTS public.downloads (
    id SERIAL PRIMARY KEY,
    dataset_id VARCHAR(50),
    resource_id VARCHAR(50),
    user_id VARCHAR(50),
    date DATE DEFAULT CURRENT_DATE
);

-- View para expor o total de downloads por recurso
CREATE OR REPLACE VIEW resources_total AS
SELECT
    row_number() OVER (ORDER BY resource_id) as __id,
    resource_id,
    dataset_id,
    count(*) as download_resource
FROM downloads
GROUP BY resource_id, dataset_id;

-- 3. Dataservices
-- Tabela para métricas de serviços de dados
CREATE TABLE IF NOT EXISTS public.dataservices (
    id SERIAL PRIMARY KEY,
    dataservice_id VARCHAR(50),
    metric_month DATE,
    visit_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- View para expor total de visitas por dataservice
CREATE OR REPLACE VIEW dataservices_total AS
SELECT
    row_number() OVER (ORDER BY dataservice_id) AS __id,
    dataservice_id,
    COALESCE(SUM(visit_count), 0) AS visit
FROM dataservices
GROUP BY dataservice_id;

-- 4. Reuses
-- Tabela para métricas de reutilizações
CREATE TABLE IF NOT EXISTS public.reuses (
    id SERIAL PRIMARY KEY,
    reuse_id VARCHAR(50),
    metric_month DATE,
    visit_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- View para expor total de visitas por reuse
CREATE OR REPLACE VIEW reuses_total AS
SELECT
    row_number() OVER (ORDER BY reuse_id) AS __id,
    reuse_id,
    COALESCE(SUM(visit_count), 0) AS visit
FROM reuses
GROUP BY reuse_id;

-- 5. Organizations
-- Tabela para métricas de organizações
CREATE TABLE IF NOT EXISTS public.organizations (
    id SERIAL PRIMARY KEY,
    organization_id VARCHAR(50),
    metric_month DATE,
    visit_dataset_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- View para expor total de visitas a datasets por organização
CREATE OR REPLACE VIEW organizations_total AS
SELECT
    row_number() OVER (ORDER BY organization_id) AS __id,
    organization_id,
    COALESCE(SUM(visit_dataset_count), 0) AS visit_dataset
FROM organizations
GROUP BY organization_id;

-- 6. Permissões
-- Ajustar 'postgres' conforme o utilizador configurado no PostgREST se for diferente
GRANT SELECT, INSERT, UPDATE, DELETE ON public.datasets TO postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.downloads TO postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.dataservices TO postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.reuses TO postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.organizations TO postgres;

GRANT SELECT ON datasets_total TO postgres;
GRANT SELECT ON resources_total TO postgres;
GRANT SELECT ON dataservices_total TO postgres;
GRANT SELECT ON reuses_total TO postgres;
GRANT SELECT ON organizations_total TO postgres;

-- 7. Recarregar Schema do PostgREST
-- Essencial para que o PostgREST detecte as novas tabelas e views sem reiniciar
NOTIFY pgrst, 'reload schema';


-- 1. Datasets
DROP VIEW IF EXISTS public.datasets_total CASCADE;
DROP VIEW IF EXISTS public.datasets_view CASCADE;

-- Rename columns if they already exist with old names
DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='datasets' AND column_name='visit_count') THEN
        ALTER TABLE public.datasets RENAME COLUMN visit_count TO monthly_visit;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='datasets' AND column_name='download_count') THEN
        ALTER TABLE public.datasets RENAME COLUMN download_count TO monthly_download_resource;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.datasets (
    id SERIAL PRIMARY KEY,
    dataset_id VARCHAR(50),
    metric_month DATE,
    monthly_visit INTEGER DEFAULT 0,
    monthly_download_resource INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Add __id column if it doesn't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='datasets' AND column_name='__id') THEN
        ALTER TABLE public.datasets ADD COLUMN __id INTEGER GENERATED ALWAYS AS (id) STORED;
    END IF;
END $$;

CREATE OR REPLACE VIEW public.datasets_total AS
SELECT 
    dataset_id,
    SUM(monthly_visit) as visit,
    SUM(monthly_download_resource) as download_resource,
    MAX(id) as __id
FROM public.datasets
GROUP BY dataset_id;


-- 2. Resources
DROP VIEW IF EXISTS public.resources_total CASCADE;

DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='resources' AND column_name='download_count') THEN
        ALTER TABLE public.resources RENAME COLUMN download_count TO monthly_download;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.resources (
    id SERIAL PRIMARY KEY,
    resource_id VARCHAR(50),
    dataset_id VARCHAR(50),
    metric_month DATE,
    monthly_download INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='resources' AND column_name='__id') THEN
        ALTER TABLE public.resources ADD COLUMN __id INTEGER GENERATED ALWAYS AS (id) STORED;
    END IF;
END $$;

CREATE OR REPLACE VIEW public.resources_total AS
SELECT 
    resource_id,
    SUM(monthly_download) as download,
    MAX(id) as __id
FROM public.resources
GROUP BY resource_id;


-- 3. Data Services
DROP VIEW IF EXISTS public.dataservices_total CASCADE;

DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='dataservices' AND column_name='visit_count') THEN
        ALTER TABLE public.dataservices RENAME COLUMN visit_count TO monthly_visit;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.dataservices (
    id SERIAL PRIMARY KEY,
    dataservice_id VARCHAR(50),
    metric_month DATE,
    monthly_visit INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='dataservices' AND column_name='__id') THEN
        ALTER TABLE public.dataservices ADD COLUMN __id INTEGER GENERATED ALWAYS AS (id) STORED;
    END IF;
END $$;

CREATE OR REPLACE VIEW public.dataservices_total AS
SELECT 
    dataservice_id,
    SUM(monthly_visit) as visit,
    MAX(id) as __id
FROM public.dataservices
GROUP BY dataservice_id;


-- 4. Reuses
DROP VIEW IF EXISTS public.reuses_total CASCADE;

DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='reuses' AND column_name='visit_count') THEN
        ALTER TABLE public.reuses RENAME COLUMN visit_count TO monthly_visit;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.reuses (
    id SERIAL PRIMARY KEY,
    reuse_id VARCHAR(50),
    metric_month DATE,
    monthly_visit INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='reuses' AND column_name='__id') THEN
        ALTER TABLE public.reuses ADD COLUMN __id INTEGER GENERATED ALWAYS AS (id) STORED;
    END IF;
END $$;

CREATE OR REPLACE VIEW public.reuses_total AS
SELECT 
    reuse_id,
    SUM(monthly_visit) as visit,
    MAX(id) as __id
FROM public.reuses
GROUP BY reuse_id;


-- 5. Organizations
DROP VIEW IF EXISTS public.organizations_total CASCADE;

DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='organizations' AND column_name='visit_dataset_count') THEN
        ALTER TABLE public.organizations RENAME COLUMN visit_dataset_count TO monthly_visit_dataset;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='organizations' AND column_name='download_resource_count') THEN
        ALTER TABLE public.organizations RENAME COLUMN download_resource_count TO monthly_download_resource;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='organizations' AND column_name='visit_reuse_count') THEN
        ALTER TABLE public.organizations RENAME COLUMN visit_reuse_count TO monthly_visit_reuse;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.organizations (
    id SERIAL PRIMARY KEY,
    organization_id VARCHAR(50),
    metric_month DATE,
    monthly_visit_dataset INTEGER DEFAULT 0,
    monthly_download_resource INTEGER DEFAULT 0,
    monthly_visit_reuse INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='organizations' AND column_name='__id') THEN
        ALTER TABLE public.organizations ADD COLUMN __id INTEGER GENERATED ALWAYS AS (id) STORED;
    END IF;
END $$;

CREATE OR REPLACE VIEW public.organizations_total AS
SELECT 
    organization_id,
    SUM(monthly_visit_dataset) as visit_dataset,
    SUM(monthly_download_resource) as download_resource,
    SUM(monthly_visit_reuse) as visit_reuse,
    MAX(id) as __id
FROM public.organizations
GROUP BY organization_id;


-- Grants
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL VIEWS IN SCHEMA public TO postgres;

-- Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';

-- Insert test data
-- DELETE FROM public.datasets WHERE dataset_id = '67c5a3b3b50fe67ba7aa1905';
-- INSERT INTO public.datasets (dataset_id, metric_month, monthly_visit, monthly_download_resource) 
-- VALUES ('67c5a3b3b50fe67ba7aa1905', '2026-02-01', 500, 200);


-- 0. Clean up
DROP VIEW IF EXISTS public.datasets_total CASCADE;
DROP VIEW IF EXISTS public.resources_total CASCADE;
DROP VIEW IF EXISTS public.dataservices_total CASCADE;
DROP VIEW IF EXISTS public.reuses_total CASCADE;
DROP VIEW IF EXISTS public.organizations_total CASCADE;

DROP TABLE IF EXISTS public.datasets CASCADE;
DROP TABLE IF EXISTS public.resources CASCADE;
DROP TABLE IF EXISTS public.dataservices CASCADE;
DROP TABLE IF EXISTS public.reuses CASCADE;
DROP TABLE IF EXISTS public.organizations CASCADE;

-- 1. Datasets
CREATE TABLE public.datasets (
    id SERIAL PRIMARY KEY,
    dataset_id VARCHAR(50),
    metric_month VARCHAR(7), -- Format: YYYY-MM
    monthly_visit INTEGER DEFAULT 0,
    monthly_download_resource INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    __id INTEGER GENERATED ALWAYS AS (id) STORED
);
CREATE OR REPLACE VIEW public.datasets_total AS
SELECT 
    dataset_id, 
    SUM(monthly_visit) as visit, 
    SUM(monthly_download_resource) as download_resource, 
    MAX(id) as __id
FROM public.datasets GROUP BY dataset_id;

-- 2. Resources
CREATE TABLE public.resources (
    id SERIAL PRIMARY KEY,
    resource_id VARCHAR(50),
    dataset_id VARCHAR(50),
    metric_month VARCHAR(7), -- Format: YYYY-MM
    monthly_download_resource INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    __id INTEGER GENERATED ALWAYS AS (id) STORED
);
CREATE OR REPLACE VIEW public.resources_total AS
SELECT 
    resource_id, 
    SUM(monthly_download_resource) as download_resource, 
    MAX(id) as __id
FROM public.resources GROUP BY resource_id;

-- 3. Data Services
CREATE TABLE public.dataservices (
    id SERIAL PRIMARY KEY,
    dataservice_id VARCHAR(50),
    metric_month VARCHAR(7), -- Format: YYYY-MM
    monthly_visit INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    __id INTEGER GENERATED ALWAYS AS (id) STORED
);
CREATE OR REPLACE VIEW public.dataservices_total AS
SELECT 
    dataservice_id, 
    SUM(monthly_visit) as visit, 
    MAX(id) as __id
FROM public.dataservices GROUP BY dataservice_id;

-- 4. Reuses
CREATE TABLE public.reuses (
    id SERIAL PRIMARY KEY,
    reuse_id VARCHAR(50),
    metric_month VARCHAR(7), -- Format: YYYY-MM
    monthly_visit INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    __id INTEGER GENERATED ALWAYS AS (id) STORED
);
CREATE OR REPLACE VIEW public.reuses_total AS
SELECT 
    reuse_id, 
    SUM(monthly_visit) as visit, 
    MAX(id) as __id
FROM public.reuses GROUP BY reuse_id;

-- 5. Organizations
CREATE TABLE public.organizations (
    id SERIAL PRIMARY KEY,
    organization_id VARCHAR(50),
    metric_month VARCHAR(7), -- Format: YYYY-MM
    monthly_visit_dataset INTEGER DEFAULT 0,
    monthly_download_resource INTEGER DEFAULT 0,
    monthly_visit_reuse INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    __id INTEGER GENERATED ALWAYS AS (id) STORED
);
CREATE OR REPLACE VIEW public.organizations_total AS
SELECT 
    organization_id, 
    SUM(monthly_visit_dataset) as visit_dataset, 
    SUM(monthly_download_resource) as download_resource, 
    SUM(monthly_visit_reuse) as visit_reuse, 
    MAX(id) as __id
FROM public.organizations GROUP BY organization_id;

-- Grants
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL VIEWS IN SCHEMA public TO postgres;

-- Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';

-- Insert test data (Using YYYY-MM format)
-- INSERT INTO public.datasets (dataset_id, metric_month, monthly_visit, monthly_download_resource) 
-- VALUES ('67c5a3b3b50fe67ba7aa1905', '2026-02', 500, 200);
