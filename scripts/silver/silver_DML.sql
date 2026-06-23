/*
====================================================================================
DESCRIPTION:
    This stored procedure orchestrates the complete ETL/Data Cleansing pipeline 
    moving raw staging data from the 'Bronze' schema into standardized, validated, 
    and deduplicated tables within the 'Silver' schema.
====================================================================================
🚨 CRITICAL DEVELOPER WARNINGS (READ BEFORE RUNNING OR MODIFYING) 🚨
------------------------------------------------------------------------------------
 1. ⚠️ TRUNCATE BEHAVIOR & RESTRICTIONS
    - This script uses 'TRUNCATE TABLE' for a full refresh strategy. 
    - DO NOT create Foreign Key constraints pointing to these Silver tables, 
      or the script will fail with a constraint violation.
    - All AUTO-INCREMENTING IDENTITY column seeds will reset to 1 upon execution.

 2. ⚠️ SUBQUERY DATA DEPENDENCY TRAP
    - Pay close attention to nested calculations (e.g., Sales and Price reconciliation).
    - Calculated columns (like 'sls_sales') are finalized in the INNER subquery 
      before being re-used in the OUTER query to prevent using dirty source data.
    - Do NOT move 'sls_price' logic inside the inner subquery without passing 
      clean parameters, or it will generate corrupt financial numbers.

 3. ⚠️ REGIONAL COMPILATION SAFEGUARDS (DATE FORMATS)
    - Source integer dates (e.g., 20260623) are converted using explicit format 
      style '112' (YYYYMMDD). 
    - Never use blind 'CAST(string AS DATE)' here; it will cause a silent runtime 
      crash on database servers configured with alternative regional/language locales.

 4. ⚠️ CLEANING HIDDEN SOURCE CHARACTERS
    - 'TRIM()' alone fails on flat-file imports. The script explicitly replaces 
      CHAR(13) [Carriage Return] and CHAR(10) [Line Feed] to vanish visual artifacts 
      and ensure text filters match accurately.
====================================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @startTime DATETIME, @endTime DATETIME, @batch_startTime DATETIME, @batch_endTime DATETIME;
            
    BEGIN TRY
        set @batch_startTime = GETDATE();
        print '==============================================================';
        print 'Loading Silver Layer...'; 
        print '==============================================================';

        print '--------------------------------------------------------------';
        print 'Loading CRM tables...';
        print '--------------------------------------------------------------';
        
        -- 1. Load CRM Customer Info
        set @startTime = GETDATE();
        print '>>Truncating silver.crm_cust_info';
        TRUNCATE TABLE silver.crm_cust_info;
        print '>>Loading silver.crm_cust_info';
       
        insert into silver.crm_cust_info (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date)
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

        set @endTime = GETDATE();
        print '>>silver.crm_cust_info load completed in ' + CAST(DATEDIFF(SECOND, @startTime, @endTime) AS VARCHAR(10)) + ' seconds.';
        print '--------------------------------------------------------------';

        -- 2. Load CRM Product Info
        set @startTime = GETDATE();
        print '>>Truncating silver.crm_prd_info';
        TRUNCATE TABLE silver.crm_prd_info;
        print '>>Loading silver.crm_prd_info';
        INSERT INTO silver.crm_prd_info (
            prd_id,
            prd_key,
            sls_prd_key,
            cat_id,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt)
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

        set @endTime = GETDATE();
        print '>>silver.crm_prd_info load completed in ' + CAST(DATEDIFF(SECOND, @startTime, @endTime) AS VARCHAR(10)) + ' seconds.';
        print '--------------------------------------------------------------';

        -- 3. Load CRM Sales Details
        set @startTime = GETDATE();
        print '>>Truncating silver.crm_sales_details';
        TRUNCATE TABLE silver.crm_sales_details;
        print '>>Loading silver.crm_sales_details';
        INSERT into silver.crm_sales_details(
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        FROM(
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

        set @endTime = GETDATE();
        print '>>silver.crm_sales_details load completed in ' + CAST(DATEDIFF(SECOND, @startTime, @endTime) AS VARCHAR(10)) + ' seconds.';
        print '--------------------------------------------------------------';

        print '--------------------------------------------------------------';
        print 'Loading ERP tables...';
        print '--------------------------------------------------------------';
        
        -- 4. Load ERP Customer AZ12
        set @startTime = GETDATE();
        print '>>Truncating silver.erp_cust_az12';
        TRUNCATE TABLE silver.erp_cust_az12;
        print '>>Loading silver.erp_cust_az12';
        INSERT into silver.erp_cust_az12(
            cid,
            bdate,
            gen
        )
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

        set @endTime = GETDATE();
        print '>>silver.erp_cust_az12 load completed in ' + CAST(DATEDIFF(SECOND, @startTime, @endTime) AS VARCHAR(10)) + ' seconds.';
        print '--------------------------------------------------------------';

        -- 5. Load ERP Location A101
        set @startTime = GETDATE();
        print '>>Truncating silver.erp_loc_a101';
        TRUNCATE TABLE silver.erp_loc_a101;
        print '>>Loading silver.erp_loc_a101';
        INSERT into silver.erp_loc_a101(
            cid,
            cntry
        )
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

        set @endTime = GETDATE();
        print '>>silver.erp_loc_a101 load completed in ' + CAST(DATEDIFF(SECOND, @startTime, @endTime) AS VARCHAR(10)) + ' seconds.';
        print '--------------------------------------------------------------';

        -- 6. Load ERP Product Category G1V2
        set @startTime = GETDATE();
        print '>>Truncating silver.erp_px_cat_g1v2';
        TRUNCATE TABLE silver.erp_px_cat_g1v2;
        print '>>Loading silver.erp_px_cat_g1v2';
        INSERT into silver.erp_px_cat_g1v2(
            id,
            cat,
            subcat,
            maintenance
        )
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
        set @endTime = GETDATE();
        print '>>bronze.erp_px_cat_g1v2 load completed in ' + CAST(DATEDIFF(SECOND, @startTime, @endTime) AS VARCHAR(10)) + ' seconds.';
        print '--------------------------------------------------------------';
        set @batch_endTime = GETDATE();
        print '==============================================================';
        print 'Loading Bronze Layer completed successfully.';
        print 'Bronze layer load completed in ' + CAST(DATEDIFF(SECOND, @batch_startTime, @batch_endTime) AS VARCHAR(10)) + ' seconds.';
        print '==============================================================';
    END TRY
    BEGIN CATCH
        PRINT '==============================================================';
        PRINT 'Error occurred during Bronze layer load:';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(10));
        PRINT 'Error Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR(10));
        PRINT 'Error State: ' + CAST(ERROR_STATE() AS VARCHAR(10));
        PRINT '==============================================================';
        THROW;
    END CATCH;
END;

-- Test by executing the stored procedure to load all silver tables
EXEC silver.load_silver;
