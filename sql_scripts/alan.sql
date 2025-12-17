-- Overall Conversion Rate (CVR)
SELECT 
    Variation,
    MAX(CASE WHEN process_step = 'start' THEN unique_visitors END) AS total_starters,
    MAX(CASE WHEN process_step = 'confirm' THEN unique_visitors END) AS total_conversions,
    (MAX(CASE WHEN process_step = 'confirm' THEN unique_visitors END) / 
     MAX(CASE WHEN process_step = 'start' THEN unique_visitors END)) * 100 AS conversion_rate_pct
FROM abtest.page_engagement_summary
GROUP BY Variation;

-- Full funnel performance
WITH StartCounts AS (
    SELECT Variation, unique_visitors as starters
    FROM abtest.page_engagement_summary
    WHERE process_step = 'start'
)
SELECT 
    p.Variation,
    p.process_step,
    p.unique_visitors,
    (p.unique_visitors / s.starters) * 100 AS pct_of_starters_reached
FROM abtest.page_engagement_summary p
JOIN StartCounts s ON p.Variation = s.Variation
ORDER BY p.Variation, 
         FIELD(p.process_step, 'start', 'step_1', 'step_2', 'step_3', 'confirm');
         
-- Step by step drop-off analysis
SELECT 
    Variation,
    process_step,
    unique_visitors,
    LAG(unique_visitors) OVER (PARTITION BY Variation ORDER BY FIELD(process_step, 'start', 'step_1', 'step_2', 'step_3', 'confirm')) AS prev_step_visitors,
    (unique_visitors / LAG(unique_visitors) OVER (PARTITION BY Variation ORDER BY FIELD(process_step, 'start', 'step_1', 'step_2', 'step_3', 'confirm'))) * 100 AS retention_from_prev_step_pct
FROM abtest.page_engagement_summary;

-- Comparison of visits vs visitors
SELECT 
    Variation,
    process_step,
    unique_visits,
    unique_visitors,
    (unique_visits / unique_visitors) AS visits_per_visitor_ratio
FROM abtest.page_engagement_summary
ORDER BY Variation, FIELD(process_step, 'start', 'step_1', 'step_2', 'step_3', 'confirm');

-- summary of lift
SELECT 
    'Conversion Lift' AS metric,
    control_cr.cr AS control_rate,
    test_cr.cr AS test_rate,
    ((test_cr.cr - control_cr.cr) / control_cr.cr) * 100 AS lift_pct
FROM 
    (SELECT (MAX(CASE WHEN process_step = 'confirm' THEN unique_visitors END) / 
             MAX(CASE WHEN process_step = 'start' THEN unique_visitors END)) AS cr 
     FROM abtest.page_engagement_summary WHERE Variation = 'Control') AS control_cr,
    (SELECT (MAX(CASE WHEN process_step = 'confirm' THEN unique_visitors END) / 
             MAX(CASE WHEN process_step = 'start' THEN unique_visitors END)) AS cr 
     FROM abtest.page_engagement_summary WHERE Variation = 'Test') AS test_cr;
     
     
     
-- calculate z-score
-- info: if z score is > 2.96, the result is not due to random chance (confidence 95%)
-- if z score is negative, the test version performed worse than control version
-- if z score is between -1.96 and 1.96 the result is not statistically significant
     WITH Stats AS (
    --  N (starters) and X (converters) for both groups
    SELECT 
        Variation,
        MAX(CASE WHEN process_step = 'start' THEN unique_visitors END) AS n,
        MAX(CASE WHEN process_step = 'confirm' THEN unique_visitors END) AS x
    FROM abtest.page_engagement_summary
    GROUP BY Variation
),
Calculations AS (
    SELECT 
        -- Control stats
        c.n AS n_ctrl, 
        c.x AS x_ctrl,
        (c.x * 1.0 / c.n) AS p_ctrl,
        -- Test stats
        t.n AS n_test, 
        t.x AS x_test,
        (t.x * 1.0 / t.n) AS p_test,
        -- Pooled proportion (p-hat)
        ((c.x + t.x) * 1.0 / (c.n + t.n)) AS p_pooled
    FROM Stats c
    JOIN Stats t ON c.Variation = 'Control' AND t.Variation = 'Test'
)
SELECT 
    p_ctrl AS control_conversion_rate,
    p_test AS test_conversion_rate,
    (p_test - p_ctrl) AS absolute_difference,
    -- Calculate Z-score: (p1 - p2) / SE
    (p_test - p_ctrl) / 
        SQRT(p_pooled * (1 - p_pooled) * (1.0/n_ctrl + 1.0/n_test)) AS z_score
FROM Calculations;