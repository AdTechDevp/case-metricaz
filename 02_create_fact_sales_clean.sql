-- ============================================================
-- 02. CRIAÇÃO DA CAMADA LIMPA
-- ============================================================

-- Remove a versão anterior, que havia sido criada com
-- particionamento por data.
DROP TABLE IF EXISTS
  `freelyweb.ds_case_vendas.fact_sales_clean`;


-- Cria a tabela limpa sem particionamento.
CREATE TABLE
  `freelyweb.ds_case_vendas.fact_sales_clean`

CLUSTER BY
  product_category,
  region,
  channel

OPTIONS (
  description = 'Tabela limpa e tipada de vendas do case Metricaz'
)

AS

WITH deduplicated AS (

  -- Remove registros integralmente idênticos.
  SELECT DISTINCT *
  FROM `freelyweb.ds_case_vendas.stg_sales_raw`

),

parsed AS (

  SELECT

    -- ========================================================
    -- IDENTIFICADORES E DATA
    -- ========================================================

    NULLIF(TRIM(order_id), '') AS order_id,

    SAFE_CAST(
      TRIM(order_date) AS DATE
    ) AS order_date,

    NULLIF(
      TRIM(customer_id),
      ''
    ) AS customer_id,

    NULLIF(
      TRIM(customer_name),
      ''
    ) AS customer_name,


    -- ========================================================
    -- LOCALIZAÇÃO
    -- ========================================================

    NULLIF(
      TRIM(region),
      ''
    ) AS region,

    UPPER(
      NULLIF(
        TRIM(state),
        ''
      )
    ) AS state,


    -- ========================================================
    -- DIMENSÕES COMERCIAIS
    -- ========================================================

    NULLIF(
      TRIM(channel),
      ''
    ) AS channel,

    NULLIF(
      TRIM(product_category),
      ''
    ) AS product_category,

    NULLIF(
      TRIM(product_name),
      ''
    ) AS product_name,


    -- ========================================================
    -- QUANTIDADE
    -- ========================================================

    SAFE_CAST(
      TRIM(quantity) AS INT64
    ) AS quantity,


    -- ========================================================
    -- PREÇO UNITÁRIO
    -- Trata formatos como:
    -- 89.90
    -- R$ 89,90
    -- ========================================================

    CASE

      WHEN REGEXP_CONTAINS(
        TRIM(unit_price),
        r','
      )

      THEN SAFE_CAST(

        REPLACE(
          REPLACE(
            REGEXP_REPLACE(
              TRIM(unit_price),
              r'[^0-9,.-]',
              ''
            ),
            '.',
            ''
          ),
          ',',
          '.'
        )

        AS NUMERIC
      )

      ELSE SAFE_CAST(

        REGEXP_REPLACE(
          TRIM(unit_price),
          r'[^0-9.-]',
          ''
        )

        AS NUMERIC
      )

    END AS unit_price,


    -- ========================================================
    -- PERCENTUAL DE DESCONTO
    -- Trata formatos como:
    -- 0.10
    -- 10%
    -- 5 %
    -- ========================================================

    CASE

      WHEN REGEXP_CONTAINS(
        TRIM(discount_pct),
        r'%'
      )

      THEN SAFE_CAST(

        REGEXP_REPLACE(
          TRIM(discount_pct),
          r'[^0-9.-]',
          ''
        )

        AS NUMERIC
      ) / 100

      ELSE SAFE_CAST(

        REPLACE(
          TRIM(discount_pct),
          ',',
          '.'
        )

        AS NUMERIC
      )

    END AS discount_pct,


    -- ========================================================
    -- CUSTO DE FRETE
    -- Trata formatos com ponto ou vírgula decimal.
    -- ========================================================

    CASE

      WHEN REGEXP_CONTAINS(
        TRIM(shipping_cost),
        r','
      )

      THEN SAFE_CAST(

        REPLACE(
          REPLACE(
            REGEXP_REPLACE(
              TRIM(shipping_cost),
              r'[^0-9,.-]',
              ''
            ),
            '.',
            ''
          ),
          ',',
          '.'
        )

        AS NUMERIC
      )

      ELSE SAFE_CAST(

        REGEXP_REPLACE(
          TRIM(shipping_cost),
          r'[^0-9.-]',
          ''
        )

        AS NUMERIC
      )

    END AS shipping_cost,


    -- ========================================================
    -- STATUS DO PAGAMENTO
    -- Padroniza Paid e paid como paid.
    -- ========================================================

    LOWER(
      NULLIF(
        TRIM(payment_status),
        ''
      )
    ) AS payment_status,


    -- ========================================================
    -- INDICADOR DE DEVOLUÇÃO
    -- Converte os valores textuais para BOOL.
    -- ========================================================

    CASE UPPER(TRIM(returned))

      WHEN 'TRUE' THEN TRUE

      WHEN 'FALSE' THEN FALSE

      ELSE NULL

    END AS returned,


    -- ========================================================
    -- RESPONSÁVEL PELA VENDA
    -- ========================================================

    NULLIF(
      TRIM(salesperson),
      ''
    ) AS salesperson

  FROM deduplicated

),

valid_rows AS (

  SELECT
    *,

    -- Receita líquida conforme a regra do enunciado.
    -- O frete não compõe a receita.
    ROUND(
      quantity
      * unit_price
      * (1 - discount_pct),
      2
    ) AS net_revenue

  FROM parsed

  WHERE

    -- Identificadores e data.
    order_id IS NOT NULL

    AND order_date IS NOT NULL


    -- Dimensões necessárias para as análises.
    AND product_category IS NOT NULL

    AND product_name IS NOT NULL

    AND region IS NOT NULL

    AND channel IS NOT NULL


    -- Quantidade válida.
    AND quantity IS NOT NULL

    AND quantity > 0


    -- Preço válido.
    AND unit_price IS NOT NULL

    AND unit_price >= 0


    -- Desconto entre 0% e 100%.
    AND discount_pct IS NOT NULL

    AND discount_pct BETWEEN 0 AND 1


    -- Frete válido.
    AND shipping_cost IS NOT NULL

    AND shipping_cost >= 0


    -- Status permitidos na base.
    AND payment_status IN (
      'paid',
      'pending',
      'cancelled'
    )


    -- Indicador de devolução convertido corretamente.
    AND returned IS NOT NULL

)

SELECT

  order_id,

  order_date,

  customer_id,

  customer_name,

  region,

  state,

  channel,

  product_category,

  product_name,

  quantity,

  unit_price,

  discount_pct,

  shipping_cost,

  payment_status,

  returned,

  salesperson,


  -- Receita definida pelo enunciado.
  net_revenue,


  -- Venda elegível para reconhecimento:
  -- pagamento realizado e sem devolução.
  (
    payment_status = 'paid'
    AND returned = FALSE
  ) AS is_revenue_eligible,


  -- Receita complementar reconhecida.
  CASE

    WHEN
      payment_status = 'paid'
      AND returned = FALSE

    THEN net_revenue

    ELSE CAST(0 AS NUMERIC)

  END AS recognized_net_revenue

FROM valid_rows;


-- ============================================================
-- VALIDAÇÕES APÓS A CRIAÇÃO
-- ============================================================

ASSERT (
  SELECT COUNT(*)
  FROM `freelyweb.ds_case_vendas.fact_sales_clean`
) = 4998
AS 'A fact_sales_clean deveria conter 4.998 linhas';


ASSERT (
  SELECT COUNTIF(is_revenue_eligible)
  FROM `freelyweb.ds_case_vendas.fact_sales_clean`
) = 4895
AS 'A fact_sales_clean deveria conter 4.895 linhas elegíveis';


ASSERT (
  SELECT COUNT(
    DISTINCT FORMAT_DATE(
      '%Y-%m',
      order_date
    )
  )
  FROM `freelyweb.ds_case_vendas.fact_sales_clean`
) = 6
AS 'A fact_sales_clean deveria conter seis meses';


-- ============================================================
-- RESUMO FINAL
-- ============================================================

SELECT

  COUNT(*) AS total_rows,

  COUNTIF(
    is_revenue_eligible
  ) AS revenue_eligible_rows,

  MIN(order_date) AS min_order_date,

  MAX(order_date) AS max_order_date,

  COUNT(
    DISTINCT FORMAT_DATE(
      '%Y-%m',
      order_date
    )
  ) AS total_months,

  ROUND(
    SUM(net_revenue),
    2
  ) AS total_net_revenue,

  ROUND(
    SUM(recognized_net_revenue),
    2
  ) AS total_recognized_net_revenue

FROM `freelyweb.ds_case_vendas.fact_sales_clean`;