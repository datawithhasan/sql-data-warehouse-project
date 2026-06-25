SELECT * FROM silver.crm_prd_info;
SELECT * FROM silver.erp_px_cat_g1v2;


/*
check if there is any duplicate value
*/
SELECT 
    sls_prd_key,
    COUNT(*)
FROM
    (SELECT
        pi.prd_id,
        pi.sls_prd_key,
        pi.cat_id,
        pi.prd_nm,
        pi.prd_cost,
        pi.prd_line,
        pi.prd_start_dt,
        pc.CAT,
        pc.SUBCAT,
        pc.MAINTENANCE
    FROM silver.crm_prd_info pi
    LEFT JOIN silver.erp_px_cat_g1v2 pc
    ON pi.cat_id = pc.ID
    WHERE prd_end_dt IS NULL --filter out all the historical data
    )t
GROUP BY sls_prd_key
HAVING COUNT(*) > 1;

/*
checking data from the view
*/
-- SELECT * FROM gold.dim_products;