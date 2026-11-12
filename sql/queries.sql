-- Kenya World Bank-financed contract awards: SQL queries (SQLite)
-- Table: awards (one row = one supplier's share of a contract award)

-- Q1: Spend by category
SELECT category,
  COUNT(*) AS n,
  ROUND(SUM(amount_usd)) AS spend,
  ROUND(100.0 * SUM(amount_usd) /
    (SELECT SUM(amount_usd) FROM awards), 1)
    AS pct
FROM awards
GROUP BY category
ORDER BY spend DESC;

-- Q2: Top 10 suppliers (firms only, UNKNOWN excluded)
SELECT supplier_key,
  COUNT(*) AS n,
  ROUND(SUM(amount_usd)) AS spend
FROM awards
WHERE is_individual = 0
  AND supplier_key <> 'UNKNOWN | XX'
GROUP BY supplier_key
ORDER BY spend DESC
LIMIT 10;

-- Q3: Pareto: how many suppliers make up 80% of firm spend
WITH s AS (
  SELECT supplier_key,
         SUM(amount_usd) AS spend
  FROM awards
  WHERE is_individual = 0
  GROUP BY supplier_key
  HAVING SUM(amount_usd) > 0),
r AS (
  SELECT supplier_key, spend,
    ROW_NUMBER() OVER (ORDER BY spend DESC)
      AS rnk,
    SUM(spend) OVER (ORDER BY spend DESC
      ROWS BETWEEN UNBOUNDED PRECEDING
      AND CURRENT ROW) AS cum
  FROM s),
p AS (
  SELECT rnk, supplier_key,
    100.0 * cum / (SELECT SUM(spend) FROM s)
      AS cp
  FROM r)
SELECT MIN(rnk) AS n_for_80,
  (SELECT COUNT(*) FROM s) AS n_suppliers
FROM p
WHERE cp >= 80;

-- Q3b: Pareto chart table: first 15 suppliers with cumulative %
WITH s AS (
  SELECT supplier_key,
         SUM(amount_usd) AS spend
  FROM awards
  WHERE is_individual = 0
  GROUP BY supplier_key
  HAVING SUM(amount_usd) > 0),
r AS (
  SELECT supplier_key, spend,
    ROW_NUMBER() OVER (ORDER BY spend DESC)
      AS rnk,
    SUM(spend) OVER (ORDER BY spend DESC
      ROWS BETWEEN UNBOUNDED PRECEDING
      AND CURRENT ROW) AS cum
  FROM s),
p AS (
  SELECT rnk, supplier_key,
    100.0 * cum / (SELECT SUM(spend) FROM s)
      AS cp
  FROM r)
SELECT rnk, supplier_key,
  ROUND(cp, 1) AS cum_pct
FROM p
WHERE rnk <= 15
ORDER BY rnk;

-- Q4: Competition share by category
SELECT category,
  ROUND(100.0 * SUM(CASE WHEN tier <> 'Direct'
    THEN amount_usd ELSE 0 END)
    / SUM(amount_usd), 1) AS any_comp_pct,
  ROUND(100.0 * SUM(CASE WHEN tier = 'Full'
    THEN amount_usd ELSE 0 END)
    / SUM(amount_usd), 1) AS full_comp_pct
FROM awards
GROUP BY category
ORDER BY full_comp_pct DESC;

-- Q4b: Full competition and local share by category, without UN agencies
SELECT category,
  ROUND(100.0 * SUM(CASE WHEN tier = 'Full'
    THEN amount_usd ELSE 0 END)
    / SUM(amount_usd), 1) AS full_pct,
  ROUND(100.0 * SUM(CASE WHEN is_kenyan = 1
    THEN amount_usd ELSE 0 END)
    / SUM(amount_usd), 1) AS local_pct
FROM awards
WHERE COALESCE(country, '') <> '1W'
GROUP BY category ORDER BY category;

-- Q5: Local share by category
SELECT category,
  ROUND(100.0 * SUM(CASE WHEN is_kenyan = 1
    THEN amount_usd ELSE 0 END)
    / SUM(amount_usd), 1) AS local_pct,
  ROUND(100.0 * SUM(CASE WHEN country IS NULL
    THEN amount_usd ELSE 0 END)
    / SUM(amount_usd), 1) AS unknown_pct
FROM awards
GROUP BY category
ORDER BY local_pct DESC;

-- Q6: Awards, spend and direct share by fiscal year
SELECT fiscal_year,
  COUNT(*) AS n_awards,
  ROUND(SUM(amount_usd)) AS spend,
  ROUND(100.0 * SUM(CASE WHEN tier = 'Direct'
    THEN amount_usd ELSE 0 END) / SUM(amount_usd), 1) AS direct_pct
FROM awards
GROUP BY fiscal_year
ORDER BY fiscal_year;
