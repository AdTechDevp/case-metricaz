-- ============================================================
-- 04. CRIAÇÃO DA CAMADA AGREGADA
-- ============================================================

CREATE OR REPLACE TABLE `freelyweb.ds_case_vendas.agg_monthly_sales` AS
SELECT
  DATE_TRUNC(order_date, MONTH) AS order_month,
  ROUND(SUM(net_revenue), 2) AS net_revenue,
  COUNT(DISTINCT order_id) AS order_count,
  ROUND(SUM(recognized_net_revenue), 2) AS recognized_net_revenue,
  COUNT(DISTINCT IF(is_revenue_eligible, order_id, NULL))
    AS eligible_order_count
FROM `freelyweb.ds_case_vendas.fact_sales_clean`
GROUP BY order_month;

CREATE OR REPLACE TABLE `freelyweb.ds_case_vendas.agg_category_sales` AS
SELECT
  product_category,
  ROUND(SUM(net_revenue), 2) AS net_revenue,
  COUNT(DISTINCT order_id) AS order_count,
  ROUND(
    SAFE_DIVIDE(
      SUM(net_revenue),
      COUNT(DISTINCT order_id)
    ),
    2
  ) AS average_ticket,
  ROUND(SUM(recognized_net_revenue), 2) AS recognized_net_revenue
FROM `freelyweb.ds_case_vendas.fact_sales_clean`
GROUP BY product_category;

CREATE OR REPLACE TABLE `freelyweb.ds_case_vendas.agg_product_sales` AS
SELECT
  product_category,
  product_name,
  ROUND(SUM(net_revenue), 2) AS net_revenue,
  COUNT(DISTINCT order_id) AS order_count,
  SUM(quantity) AS quantity_sold,
  ROUND(SUM(recognized_net_revenue), 2) AS recognized_net_revenue
FROM `freelyweb.ds_case_vendas.fact_sales_clean`
GROUP BY product_category, product_name;

CREATE OR REPLACE TABLE `freelyweb.ds_case_vendas.agg_region_channel_sales` AS
SELECT
  region,
  channel,
  ROUND(SUM(net_revenue), 2) AS net_revenue,
  COUNT(DISTINCT order_id) AS order_count,
  ROUND(SUM(recognized_net_revenue), 2) AS recognized_net_revenue
FROM `freelyweb.ds_case_vendas.fact_sales_clean`
GROUP BY region, channel;

CREATE OR REPLACE TABLE `freelyweb.ds_case_vendas.agg_category_returns` AS
SELECT
  product_category,
  COUNT(DISTINCT order_id) AS total_orders,
  COUNT(DISTINCT IF(returned = TRUE, order_id, NULL))
    AS returned_orders,
  ROUND(
    100 * SAFE_DIVIDE(
      COUNT(DISTINCT IF(returned = TRUE, order_id, NULL)),
      COUNT(DISTINCT order_id)
    ),
    2
  ) AS return_rate_pct
FROM `freelyweb.ds_case_vendas.fact_sales_clean`
GROUP BY product_category;
