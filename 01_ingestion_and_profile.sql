-- ============================================================
-- 01. INGESTÃO E PERFIL DA TABELA BRUTA
-- A ingestão do CSV foi realizada pela interface do BigQuery.
-- Autodetect: desligado
-- Schema: todas as colunas STRING
-- Delimitador: vírgula
-- Cabeçalho: 1 linha ignorada
-- Encoding: UTF-8
-- ============================================================

-- Quantidade de linhas carregadas
SELECT
  COUNT(*) AS raw_rows
FROM `freelyweb.ds_case_vendas.stg_sales_raw`;

-- Confirmação do schema da staging
SELECT
  column_name,
  data_type,
  is_nullable,
  ordinal_position
FROM `freelyweb.ds_case_vendas.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'stg_sales_raw'
ORDER BY ordinal_position;

-- Duplicidades exatas
SELECT
  COUNT(*) AS raw_rows,
  COUNT(DISTINCT TO_JSON_STRING(t)) AS unique_raw_rows,
  COUNT(*) - COUNT(DISTINCT TO_JSON_STRING(t)) AS exact_duplicate_rows
FROM `freelyweb.ds_case_vendas.stg_sales_raw` AS t;

-- Variações de status de pagamento
SELECT
  payment_status,
  COUNT(*) AS total_rows
FROM `freelyweb.ds_case_vendas.stg_sales_raw`
GROUP BY payment_status
ORDER BY total_rows DESC;

-- Quantidades que não podem ser convertidas
SELECT
  order_id,
  quantity
FROM `freelyweb.ds_case_vendas.stg_sales_raw`
WHERE SAFE_CAST(TRIM(quantity) AS INT64) IS NULL;

-- Formatos monetários não padronizados
SELECT
  order_id,
  unit_price
FROM `freelyweb.ds_case_vendas.stg_sales_raw`
WHERE REGEXP_CONTAINS(unit_price, r'[^0-9.-]');

-- Percentuais com símbolo
SELECT
  order_id,
  discount_pct
FROM `freelyweb.ds_case_vendas.stg_sales_raw`
WHERE REGEXP_CONTAINS(discount_pct, r'%');
