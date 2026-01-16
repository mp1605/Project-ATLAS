-- Check if database has any health data
-- Run this to see the current state of your database

-- 1. Check if health_metrics table exists and has data
SELECT 'Health Metrics Count:' as info, COUNT(*) as count FROM health_metrics;

-- 2. Check last 10 health data points
SELECT 
    metric_type, 
    value, 
    datetime(timestamp/1000, 'unixepoch', 'localtime') as time,
    user_email
FROM health_metrics 
ORDER BY timestamp DESC 
LIMIT 10;

-- 3. Check data by metric type
SELECT 
    metric_type, 
    COUNT(*) as count,
    MIN(datetime(timestamp/1000, 'unixepoch', 'localtime')) as earliest,
    MAX(datetime(timestamp/1000, 'unixepoch', 'localtime')) as latest
FROM health_metrics 
GROUP BY metric_type
ORDER BY count DESC;

-- 4. Check data from last 24 hours
SELECT 
    metric_type,
    COUNT(*) as count_24h
FROM health_metrics 
WHERE timestamp >= (strftime('%s', 'now') - 86400) * 1000
GROUP BY metric_type
ORDER BY count_24h DESC;

-- 5. Check user profiles
SELECT * FROM user_profiles;

-- 6. Check if we have ANY data at all
SELECT 
    (SELECT COUNT(*) FROM health_metrics) as health_count,
    (SELECT COUNT(*) FROM user_profiles) as profile_count,
    (SELECT COUNT(*) FROM training_sessions) as training_count;
