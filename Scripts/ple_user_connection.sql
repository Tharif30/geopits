dbcc sqlperf(logspace)

-- User connections
SELECT 
    'User Connections' AS metric,
    cntr_value AS current_value
FROM sys.dm_os_performance_counters
WHERE counter_name = 'User Connections'
  AND instance_name = '';

-- Page Life Expectancy (PLE) per NUMA node
SELECT 
    'Page Life Expectancy (sec)' AS metric,
    cntr_value AS current_value
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Page life expectancy';