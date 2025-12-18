-- testing base info on table page_engagement_summary
SELECT * FROM abtest.page_engagement_summary LIMIT 100;


-- Overall Conversion Rate (CVR) OLD VERSION
SELECT 
    Variation,
    MAX(CASE WHEN process_step = 'start' THEN unique_visitors END) AS total_starters,
    MAX(CASE WHEN process_step = 'confirm' THEN unique_visitors END) AS total_conversions,
    (MAX(CASE WHEN process_step = 'confirm' THEN unique_visitors END) / 
     MAX(CASE WHEN process_step = 'start' THEN unique_visitors END)) * 100 AS conversion_rate_pct
FROM abtest.page_engagement_summary
GROUP BY Variation;

-- Overall Conversion Rate (CR) NEW VERSION
SELECT 
    e.variation,
    COUNT(DISTINCT CASE WHEN w.process_step = 'start' THEN w.client_id END) AS total_starters,
    
    COUNT(DISTINCT CASE WHEN w.process_step = 'confirm' THEN w.client_id END) AS total_conversions,
    
    (COUNT(DISTINCT CASE WHEN w.process_step = 'confirm' THEN w.client_id END) * 100.0 / 
     NULLIF(COUNT(DISTINCT CASE WHEN w.process_step = 'start' THEN w.client_id END), 0)) AS conversion_rate_pct

FROM abtest.experiment e
JOIN abtest.web w ON e.client_id = w.client_id
GROUP BY e.variation;



-- Full funnel performance OLD
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
         
-- FUll funnel performance NEW
WITH StartCounts AS (
    SELECT 
        e.variation, 
        COUNT(DISTINCT s.client_id) as starters
    FROM abtest.experiment e
    JOIN abtest.web s ON e.client_id = s.client_id
    WHERE s.process_step = 'start'
    GROUP BY e.variation
)
SELECT 
    e.variation,
    w.process_step,
    COUNT(DISTINCT w.client_id) AS unique_visitors,
    (COUNT(DISTINCT w.client_id) * 100.0 / s.starters) AS pct_of_starters_reached
FROM abtest.experiment e
JOIN abtest.web w ON e.client_id = w.client_id
JOIN StartCounts s ON e.variation = s.variation
GROUP BY e.variation, w.process_step, s.starters
ORDER BY e.variation, 
         FIELD(w.process_step, 'start', 'step_1', 'step_2', 'step_3', 'confirm');
         
-- Full funnel performance TIME LOCKED
WITH SequentialSteps AS (
    SELECT 
        e.variation, 
        e.client_id, 
        MIN(w.date_time) as start_time
    FROM abtest.experiment e
    JOIN abtest.web w ON e.client_id = w.client_id
    WHERE w.process_step = 'start'
    GROUP BY e.variation, e.client_id
),
Step1 AS (
    SELECT s.variation, s.client_id, MIN(w.date_time) as step1_time
    FROM SequentialSteps s
    JOIN abtest.web w ON s.client_id = w.client_id
    WHERE w.process_step = 'step_1' AND w.date_time > s.start_time
    GROUP BY s.variation, s.client_id
),
Step2 AS (
    SELECT s.variation, s.client_id, MIN(w.date_time) as step2_time
    FROM Step1 s
    JOIN abtest.web w ON s.client_id = w.client_id
    WHERE w.process_step = 'step_2' AND w.date_time > s.step1_time
    GROUP BY s.variation, s.client_id
),
Step3 AS (
    SELECT s.variation, s.client_id, MIN(w.date_time) as step3_time
    FROM Step2 s
    JOIN abtest.web w ON s.client_id = w.client_id
    WHERE w.process_step = 'step_3' AND w.date_time > s.step2_time
    GROUP BY s.variation, s.client_id
),
Confirm AS (
    SELECT s.variation, s.client_id, MIN(w.date_time) as confirm_time
    FROM Step3 s
    JOIN abtest.web w ON s.client_id = w.client_id
    WHERE w.process_step = 'confirm' AND w.date_time > s.step3_time
    GROUP BY s.variation, s.client_id
),
FunnelCounts AS (
    SELECT variation, 'start' as process_step, COUNT(*) as unique_clients FROM SequentialSteps GROUP BY 1
    UNION ALL
    SELECT variation, 'step_1', COUNT(*) FROM Step1 GROUP BY 1
    UNION ALL
    SELECT variation, 'step_2', COUNT(*) FROM Step2 GROUP BY 1
    UNION ALL
    SELECT variation, 'step_3', COUNT(*) FROM Step3 GROUP BY 1
    UNION ALL
    SELECT variation, 'confirm', COUNT(*) FROM Confirm GROUP BY 1
)
SELECT 
    f.variation,
    f.process_step,
    f.unique_clients,
    (f.unique_clients * 100.0 / NULLIF(total.starters, 0)) AS pct_of_starters_reached
FROM FunnelCounts f
JOIN (SELECT variation, unique_clients as starters FROM FunnelCounts WHERE process_step = 'start') total
  ON f.variation = total.variation
ORDER BY f.variation, 
         FIELD(f.process_step, 'start', 'step_1', 'step_2', 'step_3', 'confirm');

         
-- Step by step drop-off analysis OLD
SELECT 
    Variation,
    process_step,
    unique_visitors,
    LAG(unique_visitors) OVER (PARTITION BY Variation ORDER BY FIELD(process_step, 'start', 'step_1', 'step_2', 'step_3', 'confirm')) AS prev_step_visitors,
    (unique_visitors / LAG(unique_visitors) OVER (PARTITION BY Variation ORDER BY FIELD(process_step, 'start', 'step_1', 'step_2', 'step_3', 'confirm'))) * 100 AS retention_from_prev_step_pct
FROM abtest.page_engagement_summary;


-- Step by step drop-off analysis NEW
WITH StepCounts AS (
    SELECT 
        e.variation,
        w.process_step,
        COUNT(DISTINCT e.client_id) AS unique_clients
    FROM abtest.experiment e
    JOIN abtest.web w ON e.client_id = w.client_id
    GROUP BY e.variation, w.process_step
)
SELECT 
    variation,
    process_step,
    unique_clients,
    LAG(unique_clients) OVER (
        PARTITION BY variation 
        ORDER BY FIELD(process_step, 'start', 'step_1', 'step_2', 'step_3', 'confirm')
    ) AS prev_step_clients,
    (unique_clients * 100.0 / 
     LAG(unique_clients) OVER (
        PARTITION BY variation 
        ORDER BY FIELD(process_step, 'start', 'step_1', 'step_2', 'step_3', 'confirm')
     )) AS retention_from_prev_step_pct
FROM StepCounts
ORDER BY variation, FIELD(process_step, 'start', 'step_1', 'step_2', 'step_3', 'confirm');



-- Comparison of visits vs visitors
SELECT 
    Variation,
    process_step,
    unique_visits,
    unique_visitors,
    (unique_visits / unique_visitors) AS visits_per_visitor_ratio
FROM abtest.page_engagement_summary
ORDER BY Variation, FIELD(process_step, 'start', 'step_1', 'step_2', 'step_3', 'confirm');

-- Comparison of visits vs visitors vs clients NEW
WITH RawMetrics AS (
    -- Aggregate all three levels of granularity
    SELECT 
        e.variation,
        w.process_step,
        COUNT(w.client_id) AS total_visits,
        COUNT(DISTINCT w.visitor_id) AS unique_visitors,
        COUNT(DISTINCT w.client_id) AS unique_clients
    FROM abtest.experiment e
    JOIN abtest.web w ON e.client_id = w.client_id
    GROUP BY e.variation, w.process_step
)
SELECT 
    variation,
    process_step,
    total_visits,
    unique_visitors,
    unique_clients,
    -- Ratio of visits per unique person
    ROUND(total_visits * 1.0 / unique_clients, 2) AS visits_per_client_ratio
FROM RawMetrics
ORDER BY variation, 
         FIELD(process_step, 'start', 'step_1', 'step_2', 'step_3', 'confirm');
         
-- Comparison visits vs visitors vs clients TIME LOCKED
WITH Step0 AS (
    SELECT e.variation, w.client_id, w.visitor_id, MIN(w.date_time) as start_time
    FROM abtest.experiment e
    JOIN abtest.web w ON e.client_id = w.client_id
    WHERE w.process_step = 'start'
    GROUP BY e.variation, w.client_id, w.visitor_id
),
Step1 AS (
    SELECT s0.*, MIN(w.date_time) as step1_time
    FROM Step0 s0
    JOIN abtest.web w ON s0.client_id = w.client_id
    WHERE w.process_step = 'step_1' AND w.date_time > s0.start_time
    GROUP BY s0.variation, s0.client_id, s0.visitor_id, s0.start_time
),
Step2 AS (
    SELECT s1.*, MIN(w.date_time) as step2_time
    FROM Step1 s1
    JOIN abtest.web w ON s1.client_id = w.client_id
    WHERE w.process_step = 'step_2' AND w.date_time > s1.step1_time
    GROUP BY s1.variation, s1.client_id, s1.visitor_id, s1.start_time, s1.step1_time
),
Step3 AS (
    SELECT s2.*, MIN(w.date_time) as step3_time
    FROM Step2 s2
    JOIN abtest.web w ON s2.client_id = w.client_id
    WHERE w.process_step = 'step_3' AND w.date_time > s2.step2_time
    GROUP BY s2.variation, s2.client_id, s2.visitor_id, s2.start_time, s2.step1_time, s2.step2_time
),
Confirm AS (
    SELECT s3.*, MIN(w.date_time) as confirm_time
    FROM Step3 s3
    JOIN abtest.web w ON s3.client_id = w.client_id
    WHERE w.process_step = 'confirm' AND w.date_time > s3.step3_time
    GROUP BY s3.variation, s3.client_id, s3.visitor_id, s3.start_time, s3.step1_time, s3.step2_time, s3.step3_time
),
FinalUnion AS (
    SELECT variation, 'start' as step, COUNT(DISTINCT client_id) as unique_clients, COUNT(DISTINCT visitor_id) as unique_visitors FROM Step0 GROUP BY 1
    UNION ALL
    SELECT variation, 'step_1', COUNT(DISTINCT client_id), COUNT(DISTINCT visitor_id) FROM Step1 GROUP BY 1
    UNION ALL
    SELECT variation, 'step_2', COUNT(DISTINCT client_id), COUNT(DISTINCT visitor_id) FROM Step2 GROUP BY 1
    UNION ALL
    SELECT variation, 'step_3', COUNT(DISTINCT client_id), COUNT(DISTINCT visitor_id) FROM Step3 GROUP BY 1
    UNION ALL
    SELECT variation, 'confirm', COUNT(DISTINCT client_id), COUNT(DISTINCT visitor_id) FROM Confirm GROUP BY 1
)
SELECT 
    variation,
    step as process_step,
    unique_visitors,
    unique_clients
FROM FinalUnion
ORDER BY variation, FIELD(process_step, 'start', 'step_1', 'step_2', 'step_3', 'confirm');

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
     
     
	-- summary of lift NEW
WITH GroupRates AS (
    SELECT 
        e.variation,
        (COUNT(DISTINCT CASE WHEN w.process_step = 'confirm' THEN e.client_id END) * 1.0 / 
         NULLIF(COUNT(DISTINCT CASE WHEN w.process_step = 'start' THEN e.client_id END), 0)) AS cr
    FROM abtest.experiment e
    JOIN abtest.web w ON e.client_id = w.client_id
    GROUP BY e.variation
)
SELECT 
    'Conversion Lift' AS metric,
    control.cr AS control_rate,
    test.cr AS test_rate,
    ((test.cr - control.cr) / NULLIF(control.cr, 0)) * 100 AS lift_pct
FROM 
    (SELECT cr FROM GroupRates WHERE variation = 'Control') AS control,
    (SELECT cr FROM GroupRates WHERE variation = 'Test') AS test;
     
     
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

-- time spent on each step
SELECT 
    Variation,
    process_step,
    AVG(seconds_to_next_step) / 60 AS avg_minutes_on_page
FROM (
    SELECT 
        Variation,
        process_step,
        TIMESTAMPDIFF(SECOND, date_time, 
            LEAD(date_time) OVER (PARTITION BY visit_id ORDER BY date_time)
        ) AS seconds_to_next_step
    FROM abtest.raw_web_data
) AS step_durations
WHERE seconds_to_next_step IS NOT NULL 
  AND seconds_to_next_step < 3600 -- Exclude sessions that timed out (over 1 hour)
GROUP BY Variation, process_step;


-- P value calc

WITH Stats AS (
    SELECT 
        Variation,
        -- Using SUM instead of MAX to ensure we aggregate all data points
        SUM(CASE WHEN process_step = 'start' THEN unique_visitors ELSE 0 END) AS n,
        SUM(CASE WHEN process_step = 'confirm' THEN unique_visitors ELSE 0 END) AS x
    FROM abtest.page_engagement_summary
    GROUP BY Variation
),
Calculations AS (
    SELECT 
        c.n AS n_ctrl, c.x AS x_ctrl, (c.x * 1.0 / NULLIF(c.n, 0)) AS p_ctrl,
        t.n AS n_test, t.x AS x_test, (t.x * 1.0 / NULLIF(t.n, 0)) AS p_test,
        ((c.x + t.x) * 1.0 / NULLIF(c.n + t.n, 0)) AS p_pooled
    FROM Stats c
    JOIN Stats t ON c.Variation = 'Control' AND t.Variation = 'Test'
),
ZScoreCalc AS (
    SELECT 
        *,
        (p_test - p_ctrl) / 
            NULLIF(SQRT(p_pooled * (1 - p_pooled) * (1.0/NULLIF(n_ctrl,0) + 1.0/NULLIF(n_test,0))), 0) AS z_score
    FROM Calculations
),
PValueApprox AS (
    SELECT 
        *,
        ABS(z_score) AS abs_z,
        1.0 / (1.0 + 0.2316419 * ABS(z_score)) AS t
    FROM ZScoreCalc
)
SELECT 
    p_ctrl AS control_conversion_rate,
    p_test AS test_conversion_rate,
    (p_test - p_ctrl) / NULLIF(p_ctrl, 0) AS relative_lift,
    z_score,
    -- P-Value Approximation for MySQL
    2 * ( (1.0 / SQRT(2 * PI())) * EXP(-0.5 * abs_z * abs_z) * (0.319381530 * t + 
         -0.356563782 * POW(t, 2) + 
         1.781477937 * POW(t, 3) + 
         -1.821255978 * POW(t, 4) + 
         1.330274429 * POW(t, 5)) ) AS p_value
FROM PValueApprox;


-- Lift, Z-Score and P-Value NEW using CLIENTS
WITH Stats AS (
    SELECT 
        e.variation,
        COUNT(DISTINCT CASE WHEN w.process_step = 'start' THEN e.client_id END) AS n,
        COUNT(DISTINCT CASE WHEN w.process_step = 'confirm' THEN e.client_id END) AS x
    FROM abtest.experiment e
    JOIN abtest.web w ON e.client_id = w.client_id
    GROUP BY e.variation
),
Calculations AS (
    SELECT 
        c.n AS n_ctrl, c.x AS x_ctrl, (c.x * 1.0 / NULLIF(c.n, 0)) AS p_ctrl,
        t.n AS n_test, t.x AS x_test, (t.x * 1.0 / NULLIF(t.n, 0)) AS p_test,
        ((c.x + t.x) * 1.0 / NULLIF(c.n + t.n, 0)) AS p_pooled
    FROM Stats c
    JOIN Stats t ON c.Variation = 'Control' AND t.Variation = 'Test'
),
ZScoreCalc AS (
    SELECT 
        *,
        (p_test - p_ctrl) / 
            NULLIF(SQRT(p_pooled * (1.0 - p_pooled) * (1.0/NULLIF(n_ctrl,0) + 1.0/NULLIF(n_test,0))), 0) AS z_score
    FROM Calculations
),
PValueApprox AS (
    SELECT 
        *,
        ABS(z_score) AS abs_z,
        1.0 / (1.0 + 0.2316419 * ABS(z_score)) AS t_val
    FROM ZScoreCalc
)
SELECT 
    p_ctrl AS control_conversion_rate,
    p_test AS test_conversion_rate,
    ((p_test - p_ctrl) / NULLIF(p_ctrl, 0)) * 100 AS lift_pct,
    z_score,
    2 * ( (1.0 / SQRT(2 * PI())) * EXP(-0.5 * abs_z * abs_z) * (
          0.319381530 * t_val + 
         -0.356563782 * POW(t_val, 2) + 
          1.781477937 * POW(t_val, 3) + 
         -1.821255978 * POW(t_val, 4) + 
          1.330274429 * POW(t_val, 5)) ) AS p_value
FROM PValueApprox;

-- Sample Ratio Mismatch query
SELECT 
    Variation, 
    SUM(CASE WHEN process_step = 'start' THEN unique_visitors ELSE 0 END) AS total_starters,
    SUM(CASE WHEN process_step = 'confirm' THEN unique_visitors ELSE 0 END) AS total_converters,
    (SUM(CASE WHEN process_step = 'confirm' THEN unique_visitors ELSE 0 END) * 1.0 / 
     SUM(CASE WHEN process_step = 'start' THEN unique_visitors ELSE 0 END)) AS conv_rate
FROM abtest.page_engagement_summary
GROUP BY Variation;

-- chi-square statistics for the traffic split
WITH RawCounts AS (
    SELECT 
        Variation,
        SUM(CASE WHEN process_step = 'start' THEN unique_visitors ELSE 0 END) AS observed_n
    FROM abtest.page_engagement_summary
    GROUP BY Variation
),
SRM_Calc AS (
    SELECT 
        SUM(observed_n) AS total_n,
        -- Observed counts for each group
        MAX(CASE WHEN Variation = 'Control' THEN observed_n END) AS o_ctrl,
        MAX(CASE WHEN Variation = 'Test' THEN observed_n END) AS o_test
    FROM RawCounts
),
ChiSquare AS (
    SELECT 
        o_ctrl,
        o_test,
        total_n,
        -- Expected count (assuming 50/50 split)
        (total_n / 2.0) AS expected_n,
        -- Chi-Square formula: Σ( (O - E)^2 / E )
        (POWER(o_ctrl - (total_n / 2.0), 2) / (total_n / 2.0)) + 
        (POWER(o_test - (total_n / 2.0), 2) / (total_n / 2.0)) AS chi_sq_stat
    FROM SRM_Calc
)
SELECT 
    o_ctrl AS control_users,
    o_test AS test_users,
    chi_sq_stat,
    -- If chi_sq_stat > 3.84, the p-value is < 0.05 (SRM is likely)
    -- If chi_sq_stat > 6.63, the p-value is < 0.01 (SRM is very likely)
    CASE 
        WHEN chi_sq_stat > 6.63 THEN 'FAIL: Massive Sample Mismatch'
        WHEN chi_sq_stat > 3.84 THEN 'WARNING: Slight Mismatch'
        ELSE 'PASS: Traffic split is healthy'
    END AS srm_status
FROM ChiSquare;


-- Assgignment leakage
SELECT client_id, COUNT(DISTINCT variation) as group_count
FROM abtest.experiment
GROUP BY client_id
HAVING group_count > 1;

-- post assignment conversion >> confirm steps that happened before the experiemnt assignment timestamp
SELECT w.client_id, w.date_time as event_time, e.variation
FROM abtest.web w
JOIN abtest.experiment e ON w.client_id = e.client_id
WHERE w.process_step = 'confirm'
