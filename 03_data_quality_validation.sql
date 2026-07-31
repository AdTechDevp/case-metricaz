-- ============================================================
-- 03. VALIDAÇÕES DE QUALIDADE
-- ============================================================

-- Resumo do volume de dados
WITH raw_statistics AS (
  SELECT
    COUNT(*) AS raw_rows,
    COUNT(DISTINCT TO_JSON_STRING(t)) AS unique_raw_rows
  FROM `freelyweb.ds_case_vendas.stg_sales_raw` AS t
),
clean_statistics AS (
  SELECT
    COUNT(*) AS clean_rows,
    COUNTIF(is_revenue_eligible) AS revenue_eligible_rows
  FROM `freelyweb.ds_case_vendas.fact_sales_clean`
)
SELECT
  raw_rows,
  unique_raw_rows,
  raw_rows - unique_raw_rows AS exact_duplicate_rows,
  clean_rows,
  revenue_eligible_rows
FROM raw_statistics
CROSS JOIN clean_statistics;

-- Campos obrigatórios nulos
SELECT
  COUNTIF(order_id IS NULL) AS null_order_id,
  COUNTIF(order_date IS NULL) AS null_order_date,
  COUNTIF(quantity IS NULL) AS null_quantity,
  COUNTIF(unit_price IS NULL) AS null_unit_price,
  COUNTIF(discount_pct IS NULL) AS null_discount_pct,
  COUNTIF(net_revenue IS NULL) AS null_net_revenue
FROM `freelyweb.ds_case_vendas.fact_sales_clean`;

-- Intervalos inválidos
SELECT
  COUNTIF(quantity <= 0) AS invalid_quantity,
  COUNTIF(unit_price < 0) AS invalid_unit_price,
  COUNTIF(discount_pct NOT BETWEEN 0 AND 1) AS invalid_discount,
  COUNTIF(shipping_cost < 0) AS invalid_shipping_cost
FROM `freelyweb.ds_case_vendas.fact_sales_clean`;

-- Valores normalizados
SELECT
  payment_status,
  returned,
  COUNT(*) AS total_rows
FROM `freelyweb.ds_case_vendas.fact_sales_clean`
GROUP BY payment_status, returned
ORDER BY payment_status, returned;

-- Linha rejeitada por conversão
WITH deduplicated AS (
  SELECT DISTINCT *
  FROM `freelyweb.ds_case_vendas.stg_sales_raw`
)
SELECT
  order_id,
  order_date,
  product_name,
  quantity,
  unit_price,
  discount_pct,
  CASE
    WHEN SAFE_CAST(TRIM(quantity) AS INT64) IS NULL
      THEN 'Quantidade inválida'
    WHEN SAFE_CAST(TRIM(order_date) AS DATE) IS NULL
      THEN 'Data inválida'
    ELSE 'Outro problema de conversão'
  END AS rejection_reason
FROM deduplicated
WHERE
  SAFE_CAST(TRIM(quantity) AS INT64) IS NULL
  OR SAFE_CAST(TRIM(order_date) AS DATE) IS NULL;
