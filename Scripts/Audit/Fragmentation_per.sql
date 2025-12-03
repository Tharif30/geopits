WITH frag_data AS (
    SELECT 
        avg_fragmentation_in_percent
    FROM 
        sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'SAMPLED')
    WHERE 
        index_id > 0  -- Skip heaps
        AND page_count > 100
)
SELECT 
    CASE 
        WHEN avg_fragmentation_in_percent > 90 THEN 'Greater than 90'
        WHEN avg_fragmentation_in_percent > 80 THEN '80-90%'
        WHEN avg_fragmentation_in_percent > 70 THEN '70-80%'
        WHEN avg_fragmentation_in_percent > 60 THEN '60-70%'
        WHEN avg_fragmentation_in_percent > 50 THEN '50-60%'
        WHEN avg_fragmentation_in_percent > 40 THEN '40-50%'
        WHEN avg_fragmentation_in_percent > 30 THEN '30-40%'
        WHEN avg_fragmentation_in_percent > 20 THEN '20-30%'
        WHEN avg_fragmentation_in_percent > 10 THEN '10-20%'
        ELSE '0-10%'
    END AS fragmentation_range,
    COUNT(*) AS index_count
FROM frag_data
GROUP BY 
    CASE 
        WHEN avg_fragmentation_in_percent > 90 THEN 'Greater than 90'
        WHEN avg_fragmentation_in_percent > 80 THEN '80-90%'
        WHEN avg_fragmentation_in_percent > 70 THEN '70-80%'
        WHEN avg_fragmentation_in_percent > 60 THEN '60-70%'
        WHEN avg_fragmentation_in_percent > 50 THEN '50-60%'
        WHEN avg_fragmentation_in_percent > 40 THEN '40-50%'
        WHEN avg_fragmentation_in_percent > 30 THEN '30-40%'
        WHEN avg_fragmentation_in_percent > 20 THEN '20-30%'
        WHEN avg_fragmentation_in_percent > 10 THEN '10-20%'
        ELSE '0-10%'
    END
ORDER BY 
    fragmentation_range;
