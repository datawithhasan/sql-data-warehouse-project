USE DataWarehouse;
GO

DROP VIEW gold.dim_products;
GO
CREATE VIEW gold.dim_products AS
SELECT
    ROW_NUMBER() over(order by pi.sls_prd_key, pi.prd_start_dt) as product_key,
    pi.prd_id AS product_id,
    pi.sls_prd_key AS product_number,
    pi.prd_nm AS product_name,
    pi.cat_id AS category_id,
    pc.CAT AS category,
    pc.SUBCAT AS sub_category,
    pc.MAINTENANCE AS maintenance,
    pi.prd_cost AS product_cost,
    pi.prd_line AS product_line,
    pi.prd_start_dt AS start_date
FROM silver.crm_prd_info pi
LEFT JOIN silver.erp_px_cat_g1v2 pc
ON pi.cat_id = pc.ID
WHERE prd_end_dt IS NULL --filter out all the historical data
;

