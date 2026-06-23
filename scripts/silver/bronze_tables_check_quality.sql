/*
====================================================================================
DESCRIPTION SUMMARY:
    This diagnostic script serves as the comprehensive Data Quality (DQ) profiling 
    and data validation suite for the 'Bronze' Staging Layer. 

    Its primary purpose is to scan, identify, and preview data anomalies across 
    incoming CRM and ERP source tables before data is processed into the Silver Layer.

CORE ANALYSIS SCOPE:
    1. Primary Key Integrity: Scans for duplicate identifiers and missing NULL values 
       in unique tracking fields (e.g., cst_id, prd_id).
       
    2. Structural Whitespace Audits: Uses comparison logic to find hidden or unwanted 
       leading/trailing spaces in text fields (e.g., cst_lastname, prd_nm).
       
    3. Categorical Consistency: Profiles low-cardinality columns (e.g., marital status, 
       gender, country, maintenance flags) to discover inconsistent formatting.
       
    4. Numeric & Financial Validation: Pinpoints negative values, missing data, and 
       mathematical mismatches where transactional sales totals do not equal the 
       calculated unit product price multiplied by quantity.
       
    5. Timeline & Reference Lineage: Evaluates business rule alignment by checking 
       for chronological errors (e.g., backward start/end dates), orphan product codes, 
       and missing customer records across operational boundaries.

TARGET TABLES PROFILED:
    - bronze.crm_cust_info       - bronze.erp_cust_az12
    - bronze.crm_prd_info        - bronze.erp_loc_a101
    - bronze.crm_sales_details   - bronze.erp_px_cat_g1v2
====================================================================================
*/

/*
Checking the quality of data in bronze layer tables
bronze.crm_cust_info
*/

-- check for nulls and duplicates in primary key columns 
select
    cst_id,
    count(*) as cnt
from bronze.crm_cust_info
group by cst_id
having count(*) > 1 or cst_id is null;

-- check for unwanted spaces in string columns 
select
    cst_lastname
from bronze.crm_cust_info
where cst_lastname != trim(cst_lastname);


-- check the consistency of the values in low cardinality columns
select distinct
    cst_marital_status
from bronze.crm_cust_info;

-- check the consistency of the values in low cardinality columns
select distinct
    cst_gndr
from bronze.crm_cust_info;


/*
Checking the quality of data in bronze layer tables
bronze.crm_prd_info
*/

-- check for nulls and duplicates in primary key columns
select
    prd_id,
    count(*) as cnt
from bronze.crm_prd_info
group by prd_id
having count(*) > 1 or prd_id is null;

-- check for unwanted spaces in string columns 
select
    prd_nm
from bronze.crm_prd_info
where prd_nm != trim(prd_nm);

-- check for negative value or null in numeric columns
select
    prd_cost
from bronze.crm_prd_info
where prd_cost < 0 or prd_cost is null;

-- check the consistency of the values in low cardinality columns
select distinct
    prd_line
from bronze.crm_prd_info;

-- check the date range of the date columns
select
    prd_key,
    prd_start_dt,
    prd_end_dt
from bronze.crm_prd_info
WHERE prd_start_dt > prd_end_dt or prd_start_dt is null or prd_end_dt is null;

-- check the date range of the date columns after data transformation
WITH ProcessedProducts AS (
    SELECT
        prd_key,
        prd_start_dt,
        LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt) AS modified_end_dt
    FROM bronze.crm_prd_info
)
SELECT 
    prd_key,
    prd_start_dt,
    modified_end_dt
FROM ProcessedProducts
WHERE prd_start_dt > modified_end_dt;



/*
Checking the quality of data in bronze layer tables
bronze.crm_sales_details
*/

-- select all
select * from bronze.crm_sales_details;

-- check which sls_prd_keys are not available in silver.crm_prd_info
select distinct
    sls_prd_key
from bronze.crm_sales_details
where sls_prd_key not in (select distinct sls_prd_key from silver.crm_prd_info);

-- check which sls_cust_id are not available in silver.crm_cus_info
select distinct
    sls_cust_id
from bronze.crm_sales_details
where sls_cust_id not in (select distinct cst_id from silver.crm_cust_info);

-- check for unwanted spaces in string columns 
select
    sls_prd_key
from bronze.crm_sales_details
where sls_prd_key != trim(sls_prd_key);

-- check all the date columns where value is not date, either any negative number, any 0 will be replaced by null
select
    sls_due_dt
from bronze.crm_sales_details
where sls_due_dt <= 0 
or len(cast(sls_due_dt as varchar)) != 8 
or sls_due_dt > 20270101 
or sls_due_dt < 19000101 
or sls_due_dt < sls_order_dt 
or sls_due_dt < sls_ship_dt;

-- check if sales = quantity*price or any of the values is null or negative or zero
select
    sls_sales,
    sls_quantity,
    sls_price
from bronze.crm_sales_details
where sls_sales != sls_quantity * sls_price
or sls_sales is null
or sls_quantity is null
or sls_price is null
or sls_sales <= 0
or sls_quantity <= 0
or sls_price <= 0
order by sls_sales, sls_quantity, sls_price;


-- chcek sls_sales after data transformation, if sales = quantity*price or any of the values is null or negative or zero
select
    sls_sales as old_sls_sales,
    CASE 
        WHEN sls_sales != sls_quantity * abs(sls_price) or sls_sales is null or  sls_sales<=0
        then ABS(sls_quantity * sls_price)
        else sls_sales
    END as sls_sales,
    sls_quantity,
    sls_price as old_sls_price,
    CASE 
        WHEN sls_price is null or  sls_price<=0
        then CAST(ABS(sls_sales / NULLIF(sls_quantity, 0)) AS DECIMAL(10,2))
        ELSE sls_price 
    END as sls_price
    
from bronze.crm_sales_details
where sls_sales != sls_quantity * sls_price
or sls_sales is null
or sls_quantity is null
or sls_price is null
or sls_sales <= 0
or sls_quantity <= 0
or sls_price <= 0
order by sls_sales, sls_quantity, sls_price
;


/*
erp_cust_az12
*/

-- select all
SELECT * FROM bronze.erp_cust_az12;

-- checking birth date
SELECT 
    bdate
FROM bronze.erp_cust_az12
WHERE year(bdate) < 1900 or bdate > GETDATE();

-- check the consistency of the values in low cardinality columns
select distinct
    gen
from bronze.erp_cust_az12;

-- transformation
SELECT 
    case 
        when cid like 'NAS%' then SUBSTRING(cid, 4, len(cid))
        else cid
    end as cid,
    case
        when bdate > GETDATE() then null
        else bdate
    end as bdate,
    case 
        when UPPER(TRIM(REPLACE(REPLACE(gen, char(13), ''), char(10), ''))) in ('F', 'FEMALE') THEN 'FEMALE'
        when UPPER(TRIM(REPLACE(REPLACE(gen, char(13), ''), char(10), ''))) in ('M', 'MALE') THEN 'MALE'
        else 'n/a'
    end as gen
FROM bronze.erp_cust_az12;

/*
erp_loc_a101
*/

-- select all
SELECT * from bronze.erp_loc_a101;

-- check the consistency of the values in low cardinality columns
select distinct
    cntry
from bronze.erp_loc_a101;

--check after transformation
select distinct 
    cntry
from(
SELECT 
    REPLACE(cid, '-', '') as cid,
    case 
        when UPPER(TRIM(REPLACE(REPLACE(cntry, char(13), ''), char(10), ''))) in ('USA', 'UNITED STATES', 'US') THEN 'UNITED STATES'
        when UPPER(TRIM(REPLACE(REPLACE(cntry, char(13), ''), char(10), ''))) in ('GERMANY', 'DE') THEN 'GERMANY'
        when UPPER(TRIM(REPLACE(REPLACE(cntry, char(13), ''), char(10), ''))) = '' then 'n/a'
        else UPPER(TRIM(REPLACE(REPLACE(cntry, char(13), ''), char(10), '')))
    end as cntry
FROM bronze.erp_loc_a101)t;


/*
erp_px_cat_g1v2
*/

-- select all
select * from bronze.erp_px_cat_g1v2;

-- check if any id is missing in silver.crm_prd_info table
select * from bronze.erp_px_cat_g1v2
where id not in (SELECT distinct cat_id from silver.crm_prd_info);

-- check the consistency of the values in low cardinality columns
select distinct
    MAINTENANCE
from bronze.erp_px_cat_g1v2;

-- check for unwanted spaces in string columns 
select
    subcat
from bronze.erp_px_cat_g1v2
where subcat != trim(subcat);

--check after transformation
SELECT distinct
    maintenance
FROM(
    select
        id,
        cat,
        TRIM(subcat) as subcat,
        case 
            when UPPER(TRIM(REPLACE(REPLACE(maintenance, char(13), ''), char(10), ''))) = 'YES' then 'YES'
            when UPPER(TRIM(REPLACE(REPLACE(maintenance, char(13), ''), char(10), ''))) = 'NO' then 'NO'
            else UPPER(TRIM(REPLACE(REPLACE(maintenance, char(13), ''), char(10), '')))
        end as maintenance
    from bronze.erp_px_cat_g1v2
)t;
