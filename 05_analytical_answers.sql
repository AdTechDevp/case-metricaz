-- ============================================================
-- 05. RESPOSTAS ANALÍTICAS
-- ============================================================

-- Questão 9
WITH raw_statistics AS (
  SELECT
    COUNT(*) AS raw_rows,
    COUNT(DISTINCT TO_JSON_STRING(t)) AS unique_raw_rows
  FROM `freelyweb.ds_case_vendas.stg_sales_raw` AS t
),
clean_statistics AS (
  SELECT
    COUNT(*) AS valid_clean_rows,
    COUNTIF(is_revenue_eligible) AS revenue_eligible_rows
  FROM `freelyweb.ds_case_vendas.fact_sales_clean`
)
SELECT
  raw_rows,
  raw_rows - unique_raw_rows AS exact_duplicate_rows,
  valid_clean_rows,
  revenue_eligible_rows
FROM raw_statistics
CROSS JOIN clean_statistics;

-- Questão 10
SELECT
  order_month,
  net_revenue,
  order_count
FROM `freelyweb.ds_case_vendas.agg_monthly_sales`
ORDER BY order_month;

-- Questão 11
SELECT
  product_category,
  net_revenue,
  order_count,
  average_ticket
FROM `freelyweb.ds_case_vendas.agg_category_sales`
ORDER BY net_revenue DESC;

-- Questão 12
SELECT
  product_category,
  product_name,
  net_revenue,
  order_count,
  quantity_sold
FROM `freelyweb.ds_case_vendas.agg_product_sales`
ORDER BY net_revenue DESC, product_name
LIMIT 3;

-- Questão 13
SELECT
  region,
  channel,
  net_revenue,
  order_count
FROM `freelyweb.ds_case_vendas.agg_region_channel_sales`
ORDER BY region, net_revenue DESC;

-- Questão 14
SELECT
  product_category,
  total_orders,
  returned_orders,
  return_rate_pct
FROM `freelyweb.ds_case_vendas.agg_category_returns`
ORDER BY return_rate_pct DESC, product_category;
