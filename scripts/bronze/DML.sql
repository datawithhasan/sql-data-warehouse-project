/*
===============================================================================
DML Script: Bulk Load Data into Bronze Layer via Stored Procedure
===============================================================================
Script Purpose:
    This script encapsulates the Bronze layer ETL process inside a stored 
    procedure. It truncates existing records to prevent duplication and 
    bulk-imports raw CSV files from the local Docker file system.

Prerequisites & Docker Pathing:
    - All CSV source files must be located inside the Docker container at the 
      internal directory: '/var/opt/mssql/'.
    - If files are missing, use 'docker cp' from your Mac terminal to move 
      them into the container before executing this script.

Loading Configuration:
    - FIRSTROW = 2        : Skips the header row containing column names.
    - FIELDTERMINATOR = ',': Uses a comma delimiter to split columns.
    - TABLOCK             : Applies a table-level lock during ingestion to 
                            optimise loading speed and reduce log overhead.

WARNING:
    Executing this stored procedure will permanently wipe (TRUNCATE) all existing 
    data currently inside the bronze staging tables before appending the new CSV 
    records. Ensure your CSV source files are updated and valid before running.
===============================================================================
*/


CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
    DECLARE @startTime DATETIME, @endTime DATETIME, @batch_startTime DATETIME, @batch_endTime DATETIME;
            
    BEGIN TRY
        set @batch_startTime = GETDATE();
        print '==============================================================';
        print 'Loading Bronze Layer...'; 
        print '==============================================================';

        print '--------------------------------------------------------------';
        print 'Loading CRM tables...';
        print '--------------------------------------------------------------';
        -- 1. Load CRM Customer Info
        set @startTime = GETDATE();
        print '>>Truncating bronze.crm_cust_info';
        TRUNCATE TABLE bronze.crm_cust_info;
        print '>>Loading bronze.crm_cust_info';
        BULK INSERT bronze.crm_cust_info
        FROM '/var/opt/mssql/cust_info.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        set @endTime = GETDATE();
        print '>>bronze.crm_cust_info load completed in ' + CAST(DATEDIFF(SECOND, @startTime, @endTime) AS VARCHAR(10)) + ' seconds.';
        print '--------------------------------------------------------------';

        -- 2. Load CRM Product Info
        set @startTime = GETDATE();
        print '>>Truncating bronze.crm_prd_info';
        TRUNCATE TABLE bronze.crm_prd_info;
        print '>>Loading bronze.crm_prd_info';
        BULK INSERT bronze.crm_prd_info
        FROM '/var/opt/mssql/prd_info.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        set @endTime = GETDATE();
        print '>>bronze.crm_prd_info load completed in ' + CAST(DATEDIFF(SECOND, @startTime, @endTime) AS VARCHAR(10)) + ' seconds.';
        print '--------------------------------------------------------------';

        -- 3. Load CRM Sales Details
        set @startTime = GETDATE();
        print '>>Truncating bronze.crm_sales_details';
        TRUNCATE TABLE bronze.crm_sales_details;
        print '>>Loading bronze.crm_sales_details';
        BULK INSERT bronze.crm_sales_details
        FROM '/var/opt/mssql/sales_details.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        set @endTime = GETDATE();
        print '>>bronze.crm_sales_details load completed in ' + CAST(DATEDIFF(SECOND, @startTime, @endTime) AS VARCHAR(10)) + ' seconds.';
        print '--------------------------------------------------------------';

        print '--------------------------------------------------------------';
        print 'Loading ERP tables...';
        print '--------------------------------------------------------------';
        -- 4. Load ERP Customer AZ12
        set @startTime = GETDATE();
        print '>>Truncating bronze.erp_cust_az12';
        TRUNCATE TABLE bronze.erp_cust_az12;
        print '>>Loading bronze.erp_cust_az12';
        BULK INSERT bronze.erp_cust_az12
        FROM '/var/opt/mssql/cust_az12.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        set @endTime = GETDATE();
        print '>>bronze.erp_cust_az12 load completed in ' + CAST(DATEDIFF(SECOND, @startTime, @endTime) AS VARCHAR(10)) + ' seconds.';
        print '--------------------------------------------------------------';

        -- 5. Load ERP Location A101
        set @startTime = GETDATE();
        print '>>Truncating bronze.erp_loc_a101';
        TRUNCATE TABLE bronze.erp_loc_a101;
        print '>>Loading bronze.erp_loc_a101';
        BULK INSERT bronze.erp_loc_a101
        FROM '/var/opt/mssql/loc_a101.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        set @endTime = GETDATE();
        print '>>bronze.erp_loc_a101 load completed in ' + CAST(DATEDIFF(SECOND, @startTime, @endTime) AS VARCHAR(10)) + ' seconds.';
        print '--------------------------------------------------------------';

        -- 6. Load ERP Product Category G1V2
        set @startTime = GETDATE();
        print '>>Truncating bronze.erp_px_cat_g1v2';
        TRUNCATE TABLE bronze.erp_px_cat_g1v2;
        print '>>Loading bronze.erp_px_cat_g1v2';
        BULK INSERT bronze.erp_px_cat_g1v2
        FROM '/var/opt/mssql/px_cat_g1v2.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
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

-- Test by executing the stored procedure to load all bronze tables
EXEC bronze.load_bronze;
