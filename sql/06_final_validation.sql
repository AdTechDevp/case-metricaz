-- ============================================================
-- 06. VALIDAÇÃO FINAL DOS NÚMEROS
-- Executar depois da criação das tabelas agregadas.
-- ============================================================

-- ------------------------------------------------------------
-- RESULTADO 1: controles de volume e qualidade
-- ------------------------------------------------------------

WITH raw AS (
  SELECT
    COUNT(*) AS raw_rows,
    COUNT(DISTINCT TO_JSON_STRING(t)) AS unique_raw_rows
  FROM `freelyweb.ds_case_vendas.stg_sales_raw` AS t
),
clean AS (
  SELECT
    COUNT(*) AS clean_rows,
    COUNTIF(is_revenue_eligible) AS revenue_eligible_rows,
    COUNTIF(order_id IS NULL) AS null_order_id,
    COUNTIF(order_date IS NULL) AS null_order_date,
    COUNTIF(quantity IS NULL OR quantity <= 0) AS invalid_quantity,
    COUNTIF(unit_price IS NULL OR unit_price < 0) AS invalid_unit_price,
    COUNTIF(
      discount_pct IS NULL
      OR discount_pct NOT BETWEEN 0 AND 1
    ) AS invalid_discount,
    COUNTIF(
      shipping_cost IS NULL
      OR shipping_cost < 0
    ) AS invalid_shipping_cost
  FROM `freelyweb.ds_case_vendas.fact_sales_clean`
)

SELECT
  validation_name,
  actual_value,
  expected_value,
  validation_status
FROM (
  SELECT
    1 AS validation_order,
    'Linhas da staging' AS validation_name,
    CAST(raw_rows AS STRING) AS actual_value,
    '5000' AS expected_value,
    IF(raw_rows = 5000, 'PASS', 'FAIL') AS validation_status
  FROM raw

  UNION ALL

  SELECT
    2,
    'Duplicidades exatas',
    CAST(raw_rows - unique_raw_rows AS STRING),
    '1',
    IF(raw_rows - unique_raw_rows = 1, 'PASS', 'FAIL')
  FROM raw

  UNION ALL

  SELECT
    3,
    'Linhas válidas na fact_sales_clean',
    CAST(clean_rows AS STRING),
    '4998',
    IF(clean_rows = 4998, 'PASS', 'FAIL')
  FROM clean

  UNION ALL

  SELECT
    4,
    'Linhas elegíveis para receita reconhecida',
    CAST(revenue_eligible_rows AS STRING),
    '4895',
    IF(revenue_eligible_rows = 4895, 'PASS', 'FAIL')
  FROM clean

  UNION ALL

  SELECT
    5,
    'Campos obrigatórios nulos',
    CAST(null_order_id + null_order_date AS STRING),
    '0',
    IF(null_order_id + null_order_date = 0, 'PASS', 'FAIL')
  FROM clean

  UNION ALL

  SELECT
    6,
    'Valores numéricos inválidos',
    CAST(
      invalid_quantity
      + invalid_unit_price
      + invalid_discount
      + invalid_shipping_cost
      AS STRING
    ),
    '0',
    IF(
      invalid_quantity
      + invalid_unit_price
      + invalid_discount
      + invalid_shipping_cost = 0,
      'PASS',
      'FAIL'
    )
  FROM clean
)
ORDER BY validation_order;


-- ------------------------------------------------------------
-- RESULTADO 2: reconciliação da receita entre fact e agregados
-- ------------------------------------------------------------

WITH fact AS (
  SELECT
    ROUND(SUM(net_revenue), 2) AS fact_net_revenue,
    ROUND(SUM(recognized_net_revenue), 2)
      AS fact_recognized_net_revenue
  FROM `freelyweb.ds_case_vendas.fact_sales_clean`
),

aggregates AS (
  SELECT
    (
      SELECT ROUND(SUM(net_revenue), 2)
      FROM `freelyweb.ds_case_vendas.agg_monthly_sales`
    ) AS monthly_net_revenue,

    (
      SELECT ROUND(SUM(net_revenue), 2)
      FROM `freelyweb.ds_case_vendas.agg_category_sales`
    ) AS category_net_revenue,

    (
      SELECT ROUND(SUM(net_revenue), 2)
      FROM `freelyweb.ds_case_vendas.agg_product_sales`
    ) AS product_net_revenue,

    (
      SELECT ROUND(SUM(net_revenue), 2)
      FROM `freelyweb.ds_case_vendas.agg_region_channel_sales`
    ) AS region_channel_net_revenue,

    (
      SELECT ROUND(SUM(recognized_net_revenue), 2)
      FROM `freelyweb.ds_case_vendas.agg_monthly_sales`
    ) AS monthly_recognized_net_revenue
)

SELECT
  validation_name,
  fact_value,
  aggregate_value,
  difference,
  validation_status
FROM (
  SELECT
    1 AS validation_order,
    'Receita mensal x fact' AS validation_name,
    fact_net_revenue AS fact_value,
    monthly_net_revenue AS aggregate_value,
    ROUND(monthly_net_revenue - fact_net_revenue, 2) AS difference,
    IF(
      ABS(monthly_net_revenue - fact_net_revenue) < 0.01,
      'PASS',
      'FAIL'
    ) AS validation_status
  FROM fact CROSS JOIN aggregates

  UNION ALL

  SELECT
    2,
    'Receita por categoria x fact',
    fact_net_revenue,
    category_net_revenue,
    ROUND(category_net_revenue - fact_net_revenue, 2),
    IF(
      ABS(category_net_revenue - fact_net_revenue) < 0.01,
      'PASS',
      'FAIL'
    )
  FROM fact CROSS JOIN aggregates

  UNION ALL

  SELECT
    3,
    'Receita por produto x fact',
    fact_net_revenue,
    product_net_revenue,
    ROUND(product_net_revenue - fact_net_revenue, 2),
    IF(
      ABS(product_net_revenue - fact_net_revenue) < 0.01,
      'PASS',
      'FAIL'
    )
  FROM fact CROSS JOIN aggregates

  UNION ALL

  SELECT
    4,
    'Receita por região e canal x fact',
    fact_net_revenue,
    region_channel_net_revenue,
    ROUND(region_channel_net_revenue - fact_net_revenue, 2),
    IF(
      ABS(region_channel_net_revenue - fact_net_revenue) < 0.01,
      'PASS',
      'FAIL'
    )
  FROM fact CROSS JOIN aggregates

  UNION ALL

  SELECT
    5,
    'Receita reconhecida mensal x fact',
    fact_recognized_net_revenue,
    monthly_recognized_net_revenue,
    ROUND(
      monthly_recognized_net_revenue
      - fact_recognized_net_revenue,
      2
    ),
    IF(
      ABS(
        monthly_recognized_net_revenue
        - fact_recognized_net_revenue
      ) < 0.01,
      'PASS',
      'FAIL'
    )
  FROM fact CROSS JOIN aggregates
)
ORDER BY validation_order;


-- ------------------------------------------------------------
-- RESULTADO 3: estrutura esperada da camada agregada
-- ------------------------------------------------------------

SELECT
  table_name,
  row_count,
  expected_description
FROM (
  SELECT
    'agg_monthly_sales' AS table_name,
    COUNT(*) AS row_count,
    'Um registro por mês' AS expected_description
  FROM `freelyweb.ds_case_vendas.agg_monthly_sales`

  UNION ALL

  SELECT
    'agg_category_sales',
    COUNT(*),
    'Um registro por categoria'
  FROM `freelyweb.ds_case_vendas.agg_category_sales`

  UNION ALL

  SELECT
    'agg_product_sales',
    COUNT(*),
    'Um registro por categoria e produto'
  FROM `freelyweb.ds_case_vendas.agg_product_sales`

  UNION ALL

  SELECT
    'agg_region_channel_sales',
    COUNT(*),
    'Um registro por região e canal'
  FROM `freelyweb.ds_case_vendas.agg_region_channel_sales`

  UNION ALL

  SELECT
    'agg_category_returns',
    COUNT(*),
    'Um registro por categoria'
  FROM `freelyweb.ds_case_vendas.agg_category_returns`
)
ORDER BY table_name;


-- ------------------------------------------------------------
-- RESULTADO 4: validação da taxa de devolução por categoria
-- ------------------------------------------------------------

WITH recalculated AS (
  SELECT
    product_category,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT IF(returned, order_id, NULL))
      AS returned_orders,
    ROUND(
      100 * SAFE_DIVIDE(
        COUNT(DISTINCT IF(returned, order_id, NULL)),
        COUNT(DISTINCT order_id)
      ),
      2
    ) AS return_rate_pct
  FROM `freelyweb.ds_case_vendas.fact_sales_clean`
  GROUP BY product_category
)

SELECT
  a.product_category,
  a.total_orders AS aggregate_total_orders,
  r.total_orders AS recalculated_total_orders,
  a.returned_orders AS aggregate_returned_orders,
  r.returned_orders AS recalculated_returned_orders,
  a.return_rate_pct AS aggregate_return_rate_pct,
  r.return_rate_pct AS recalculated_return_rate_pct,
  IF(
    a.total_orders = r.total_orders
    AND a.returned_orders = r.returned_orders
    AND ABS(a.return_rate_pct - r.return_rate_pct) < 0.01,
    'PASS',
    'FAIL'
  ) AS validation_status
FROM `freelyweb.ds_case_vendas.agg_category_returns` AS a
INNER JOIN recalculated AS r
  USING (product_category)
ORDER BY a.product_category;
