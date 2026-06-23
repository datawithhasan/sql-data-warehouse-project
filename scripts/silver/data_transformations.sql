/*
===================================================================================================
PURPOSE:
    This script performs comprehensive Data Extraction, Cleaning, and Standardisation 
    transformations on raw staging tables within the 'Bronze' schema. It prepares, 
    reconciles, and structures the datasets for direct, error-free loading into 
    the validated operational tables of the 'Silver' schema.

SCOPE OF OPERATIONS:
    - Standardises categorical descriptions and low-cardinality flags (Gender, Marital Status).
    - Trims redundant string whitespaces and programmatically drops corrupted formatting bytes.
    - Strips source prefix artifacts and strips trailing carriage return/line feed layout indicators.
    - Normalises numeric integer-based string dates to strict database DATE formats.
    - Reconciles financial figures using safe, division-error-shielded transaction arithmetic.
    - Deduplicates customer data records to capture only the latest system snapshot updates.

TARGETS PROFILED & TRANSFORMED:
    - Source: bronze.crm_cust_info      -> Destination: silver.crm_cust_info
    - Source: bronze.crm_prd_info       -> Destination: silver.crm_prd_info
    - Source: bronze.crm_sales_details  -> Destination: silver.crm_sales_details
    - Source: bronze.erp_cust_az12      -> Destination: silver.erp_cust_az12
    - Source: bronze.erp_loc_a101       -> Destination: silver.erp_loc_a101
    - Source: bronze.erp_px_cat_g1v2    -> Destination: silver.erp_px_cat_g1v2
===================================================================================================
*/


/*
bronze.crm_cust_info table has been checked for nulls and duplicates in primary key columns, unwanted spaces in string columns, and consistency of the values in low cardinality columns. The following query selects the data from bronze.crm_cust_info table after data transformation and quality checks to be inserted into silver.crm_cust_info table.
*/
select
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date
from (
    select 
        cst_id,
        cst_key,
        cst_create_date,
        trim(cst_firstname) as cst_firstname,
        trim(cst_lastname) as cst_lastname,
        case 
            when upper(trim(cst_marital_status)) = 'M' then 'Married'
            when upper(trim(cst_marital_status)) = 'S' then 'Single'
            else 'N/A'
        end as cst_marital_status,
        case 
            when upper(trim(cst_gndr)) = 'M' then 'Male'
            when upper(trim(cst_gndr)) = 'F' then 'Female'
            else 'N/A'
        end as cst_gndr,
        row_number() over(partition by cst_id order by cst_create_date desc) as row_number
    from bronze.crm_cust_info
    where cst_id is not null
    )t where row_number = 1;

/*
crm_prd_info
*/
select
    prd_id,
    prd_key,
    sls_prd_key,
    cat_id,
    prd_nm,
    prd_cost,
    prd_line,
    prd_start_dt,
    prd_end_dt 
from (
    select 
        prd_id,
        prd_key,
        substring(prd_key, 7, len(prd_key)) as sls_prd_key,
        replace(substring(prd_key, 1, 5), '-', '_') as cat_id,
        trim(prd_nm) as prd_nm,
        isnull(prd_cost, 0) as prd_cost,
        case 
            when upper(trim(prd_line)) = 'M' then 'Mountain'
            when upper(trim(prd_line)) = 'R' then 'Road'
            when upper(trim(prd_line)) = 'S' then 'Other Sales'
            when upper(trim(prd_line)) = 'T' then 'Touring'
            else 'N/A'
        end as prd_line,
        cast(prd_start_dt as date) as prd_start_dt,
        cast(lead(prd_start_dt) over(partition by prd_key order by prd_start_dt) as date) as prd_end_dt
    from bronze.crm_prd_info
    )t;


/*
crm_sales_details
*/
select
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    sls_sales,
    sls_quantity,
    sls_price
from (
    select
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,

        CASE 
            WHEN sls_order_dt = 0 
                OR len(cast(sls_order_dt as varchar)) != 8 
            THEN NULL
            ELSE cast(cast(sls_order_dt as varchar) as date)
        END AS sls_order_dt,

        CASE 
            WHEN sls_ship_dt = 0 
                OR len(cast(sls_ship_dt as varchar)) != 8 
            THEN NULL
            ELSE cast(cast(sls_ship_dt as varchar) as date)
        END AS sls_ship_dt,

        CASE 
            WHEN sls_due_dt = 0 
                OR len(cast(sls_due_dt as varchar)) != 8 
            THEN NULL
            ELSE cast(cast(sls_due_dt as varchar) as date)
        END AS sls_due_dt,

        CASE 
        WHEN sls_sales != sls_quantity * abs(sls_price) or sls_sales is null or  sls_sales<=0
        then ABS(sls_quantity * sls_price)
        else sls_sales
        END as sls_sales,

        sls_quantity,

        CASE 
            WHEN sls_price is null or  sls_price<=0
            then CAST(ABS(sls_sales / NULLIF(sls_quantity, 0)) AS DECIMAL(10,2))
            ELSE sls_price 
        END as sls_price
        
    from bronze.crm_sales_details
    )t ;


/*
erp_cust_az12
*/
SELECT
    cid,
    bdate,
    gen
FROM(
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
    FROM bronze.erp_cust_az12
)t;


/*
erp.loc.a101
*/
SELECT
    cid,
    cntry
FROM(
    SELECT 
    REPLACE(cid, '-', '') as cid,
    case 
        when UPPER(TRIM(REPLACE(REPLACE(cntry, char(13), ''), char(10), ''))) in ('USA', 'UNITED STATES', 'US') THEN 'UNITED STATES'
        when UPPER(TRIM(REPLACE(REPLACE(cntry, char(13), ''), char(10), ''))) in ('GERMANY', 'DE') THEN 'GERMANY'
        when UPPER(TRIM(REPLACE(REPLACE(cntry, char(13), ''), char(10), ''))) = '' then 'n/a'
        else UPPER(TRIM(REPLACE(REPLACE(cntry, char(13), ''), char(10), '')))
    end as cntry
FROM bronze.erp_loc_a101
)t;


/*
erp_px_cat_g1v2
*/

SELECT 
    id,
    cat,
    subcat,
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
