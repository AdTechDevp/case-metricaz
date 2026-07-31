# Case Técnico de Dados — Metricaz

Solução de um fluxo analítico de vendas em BigQuery, cobrindo ingestão, tratamento, modelagem, validação e respostas analíticas.

## Arquitetura

CSV local  
→ `stg_sales_raw` — staging com todos os campos como `STRING`  
→ `fact_sales_clean` — deduplicação, normalização, tipagem e cálculo de receita  
→ tabelas `agg_*` — camada agregada para consumo analítico  
→ relatório em PDF

## Estrutura do repositório

```text
sql/
├── 01_ingestion_and_profile.sql
├── 02_create_fact_sales_clean.sql
├── 03_data_quality_validation.sql
├── 04_create_aggregate_tables.sql
├── 05_analytical_answers.sql
└── 06_final_validation.sql
```

## Premissas

- `net_revenue = quantity * unit_price * (1 - discount_pct)`.
- O frete não compõe a receita líquida.
- Duplicidades exatas são removidas com `SELECT DISTINCT`.
- Registros sem conversão válida dos campos obrigatórios são excluídos da camada limpa.
- `recognized_net_revenue` é uma métrica complementar para pedidos pagos e não devolvidos.
- As respostas oficiais do case utilizam `net_revenue`, conforme o enunciado.

## Execução

Execute os scripts na ordem numérica no BigQuery.

Projeto utilizado: `freelyweb`  
Dataset utilizado: `ds_case_vendas`

## Entregáveis

- Scripts SQL reproduzíveis.
- Relatório em PDF com arquitetura, evidências, decisões de tratamento e resultados.
- Validação final dos números e reconciliação entre a tabela limpa e as tabelas agregadas.
