---
name: data-portal-mcp
description: Query Shopify data via Data Portal MCP and build dashboards (including create_dashboard with exactly 7 visualizations).
---

# Data Portal MCP

Use this skill when you need to:
- discover Shopify datasets/tables
- inspect table schema/metadata
- run BigQuery safely through MCP
- analyze query results with Python
- create dashboards

## Runtime setup

Use Node 20 before using mcporter:

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use 20
node -v
```

List tool schema:

```bash
npx mcporter list data-portal-mcp --schema
```

## Tool sequence (recommended)

For normal data exploration and querying, follow this order:

1. `list_data_platform_docs`
2. `search_data_platform`
3. `get_entry_metadata`
4. `query_bigquery`
5. `analyze_query_results` (optional)
6. `create_dashboard` (only when asked to create a dashboard)

## Key MCP calls

### 1) Platform docs

```bash
npx mcporter call data-portal-mcp.list_data_platform_docs
```

### 2) Search entities

```bash
npx mcporter call data-portal-mcp.search_data_platform \
  dataplex_query='(customer_tracking AND storefront) AND projectid:sdp-prd-buyer-engagement' \
  natural_language_query='Find storefront tracking tables for add to cart analysis'
```

### 3) Get schema/metadata

```bash
npx mcporter call data-portal-mcp.get_entry_metadata \
  fully_qualified_name='bigquery:sdp-prd-buyer-engagement.base.base__storefront_customer_tracking_5'
```

### 4) Run SQL

```bash
npx mcporter call data-portal-mcp.query_bigquery \
  query='SELECT DATE(event_timestamp) day, COUNT(*) c FROM `sdp-prd-buyer-engagement.base.base__storefront_customer_tracking_5` WHERE event_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY) GROUP BY 1 ORDER BY 1'
```

### 5) Analyze result CSV with Python

```bash
npx mcporter call data-portal-mcp.analyze_query_results \
  result_id='bq_result_abc.csv' \
  code='df = pd.read_csv("input_data.csv"); print(df.head())'
```

If analysis generates `output_plot.png`, open it:

```bash
open /path/to/output_plot.png
```

### 6) Create dashboard

`create_dashboard` requires exactly **7 visualizations**:
- 3 metrics
- 4 charts (bar/line/area/scatter/pie/table)

Use JSON args file to avoid escaping issues:

```bash
npx mcporter call data-portal-mcp.create_dashboard \
  --args "$(cat dashboard_payload.json)" \
  --output json
```

## Dashboard payload template

```json
{
  "dashboard_title": "Example Dashboard",
  "description": "Short purpose statement",
  "visualizations": [
    {
      "title": "Metric 1",
      "type": "metric",
      "description": "KPI",
      "sql_query": "SELECT 1 AS value"
    },
    {
      "title": "Metric 2",
      "type": "metric",
      "description": "KPI",
      "sql_query": "SELECT 2 AS value"
    },
    {
      "title": "Metric 3",
      "type": "metric",
      "description": "KPI",
      "sql_query": "SELECT 3 AS value"
    },
    {
      "title": "Trend",
      "type": "line",
      "description": "Time trend",
      "sql_query": "SELECT CURRENT_TIMESTAMP() AS t, 1 AS y"
    },
    {
      "title": "Breakdown",
      "type": "bar",
      "description": "Category comparison",
      "sql_query": "SELECT 'A' AS category, 1 AS value"
    },
    {
      "title": "Share",
      "type": "pie",
      "description": "Proportion",
      "sql_query": "SELECT 'A' AS segment, 1 AS value"
    },
    {
      "title": "Detail",
      "type": "table",
      "description": "Detailed rows",
      "sql_query": "SELECT 'row' AS label, 1 AS value"
    }
  ]
}
```

## Practical guardrails

- Always include partition filters (`event_timestamp >= ...`) to control scan size.
- Prefer shorter time windows first (24h, 3d, 7d), then expand.
- If dashboard creation fails with bytes processed limit, reduce time windows in heavy visualizations.
- Keep SQL outputs raw (do not pre-scale to K/M/B); dashboard auto-formats large values.

## Known constraints

- `query_bigquery` does not allow INFORMATION_SCHEMA access.
- Query validation enforces cost/scan constraints.
- `create_dashboard` can fail if any visualization query exceeds byte limits.

## One-liner: open generated dashboard

If MCP returns a URL like below:

```text
https://data-portal.quick.shopify.io/dashboards/<id>.html
```

open it with:

```bash
open https://data-portal.quick.shopify.io/dashboards/<id>.html
```
