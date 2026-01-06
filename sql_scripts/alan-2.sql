-- test performance by age group
WITH FirstStarts AS (
    SELECT 
        e.client_id, e.variation, d.client_age,
        CASE 
            WHEN d.client_age < 30 THEN 'Digital Natives (<30)'
            WHEN d.client_age BETWEEN 30 AND 49 THEN 'Mid-Career Techies (30-49)'
            WHEN d.client_age BETWEEN 50 AND 69 THEN 'Silver Surfers (50-69)'
            ELSE 'Golden Pioneers (70+)' 
        END AS age_group,
        MIN(w.date_time) AS start_time
    FROM abtest.experiment e
    JOIN abtest.web w ON e.client_id = w.client_id
    JOIN abtest.demo d ON e.client_id = d.client_id
    WHERE w.process_step = 'start'
    GROUP BY 1, 2, 3, 4
),
ValidConversions AS (
    -- Identify unique clients who converted AFTER their start time
    SELECT fs.client_id, COUNT(*) as conv_count
    FROM FirstStarts fs
    JOIN abtest.web w ON fs.client_id = w.client_id
    WHERE w.process_step = 'confirm' AND w.date_time > fs.start_time
    GROUP BY 1
),
GroupStats AS (
    -- Aggregate N and X per Age Group and Variation
    SELECT 
        fs.age_group, fs.variation,
        COUNT(DISTINCT fs.client_id) AS n,
        COUNT(DISTINCT vc.client_id) AS x
    FROM FirstStarts fs
    LEFT JOIN ValidConversions vc ON fs.client_id = vc.client_id
    GROUP BY 1, 2
),
CompareGroups AS (
    -- Pair Control and Test for each Age Group
    SELECT 
        c.age_group,
        c.n AS n_ctrl, c.x AS x_ctrl, (c.x * 1.0 / NULLIF(c.n, 0)) AS p_ctrl,
        t.n AS n_test, t.x AS x_test, (t.x * 1.0 / NULLIF(t.n, 0)) AS p_test,
        ((c.x + t.x) * 1.0 / NULLIF(c.n + t.n, 0)) AS p_pooled
    FROM GroupStats c
    JOIN GroupStats t ON c.age_group = t.age_group 
    WHERE c.variation = 'Control' AND t.variation = 'Test'
),
ZScoreCalc AS (
    -- Calculate Z-Score and P-Value per demographic
    SELECT 
        *,
        (p_test - p_ctrl) / 
            NULLIF(SQRT(p_pooled * (1.0 - p_pooled) * (1.0/NULLIF(n_ctrl,0) + 1.0/NULLIF(n_test,0))), 0) AS z_score
    FROM CompareGroups
)
SELECT 
    age_group,
    n_ctrl + n_test AS total_clients,
    ROUND(p_ctrl * 100, 2) AS control_cr_pct,
    ROUND(p_test * 100, 2) AS test_cr_pct,
    ROUND(((p_test - p_ctrl) / NULLIF(p_ctrl, 0)) * 100, 2) AS lift_pct,
    CASE 
        WHEN ABS(z_score) > 1.96 THEN 'Significant'
        ELSE 'Not Significant'
    END AS statistical_significance,
    ROUND(z_score, 4) AS z_score
FROM ZScoreCalc
ORDER BY age_group;



WITH SegmentStats AS (
    -- Define tenure groups and find first valid starts
    SELECT 
        e.variation,
        CASE 
            WHEN d.client_tenure_years < 1 THEN 'New (<1yr)'
            WHEN d.client_tenure_years BETWEEN 1 AND 5 THEN 'Established (1-5yr)'
            ELSE 'Veteran (5yr+)' 
        END AS tenure_group,
        e.client_id,
        MIN(w.date_time) AS first_start_time
    FROM abtest.experiment e
    JOIN abtest.demo d ON e.client_id = d.client_id
    JOIN abtest.web w ON e.client_id = w.client_id
    WHERE w.process_step = 'start'
    GROUP BY 1, 2, 3
),
ValidConversions AS (
    -- Identify unique clients who converted AFTER their start time
    SELECT ss.client_id
    FROM SegmentStats ss
    JOIN abtest.web w ON ss.client_id = w.client_id
    WHERE w.process_step = 'confirm' 
      AND w.date_time > ss.first_start_time
    GROUP BY 1
),
AggregatedStats AS (
    -- Count N and X for each tenure group/variation
    SELECT 
        ss.tenure_group, 
        ss.variation,
        COUNT(DISTINCT ss.client_id) AS n,
        COUNT(DISTINCT vc.client_id) AS x
    FROM SegmentStats ss
    LEFT JOIN ValidConversions vc ON ss.client_id = vc.client_id
    GROUP BY 1, 2
),
Comparison AS (
    -- Pair Control and Test for Z-score calculation
    SELECT 
        c.tenure_group,
        c.n AS ctrl_n, c.x AS ctrl_x, (c.x * 1.0 / NULLIF(c.n, 0)) AS ctrl_cr,
        t.n AS test_n, t.x AS test_x, (t.x * 1.0 / NULLIF(t.n, 0)) AS test_cr,
        ((c.x + t.x) * 1.0 / NULLIF(c.n + t.n, 0)) AS p_pooled
    FROM AggregatedStats c
    JOIN AggregatedStats t ON c.tenure_group = t.tenure_group
    WHERE c.variation = 'Control' AND t.variation = 'Test'
)
-- Calculation of Lift and Z-score per tenure segment
SELECT 
    tenure_group,
    ctrl_n + test_n AS total_sample,
    ROUND(ctrl_cr * 100, 2) AS ctrl_cr_pct,
    ROUND(test_cr * 100, 2) AS test_cr_pct,
    ROUND(((test_cr - ctrl_cr) / NULLIF(ctrl_cr, 0)) * 100, 2) AS lift_pct,
    ROUND((test_cr - ctrl_cr) / 
        NULLIF(SQRT(p_pooled * (1.0 - p_pooled) * (1.0/NULLIF(ctrl_n,0) + 1.0/NULLIF(test_n,0))), 0), 4) AS segment_z_score
FROM Comparison
ORDER BY segment_z_score DESC;






WITH SegmentStats AS (
    -- Define activity groups based on logons in the last 6 months
    SELECT 
        e.variation,
        CASE 
            WHEN d.logons_6_months <= 3 THEN 'Low Activity (0-3)'
            WHEN d.logons_6_months BETWEEN 4 AND 6 THEN 'Moderate Activity (4-6)'
            WHEN d.logons_6_months BETWEEN 7 AND 10 THEN 'High Activity (7-10)'
            ELSE 'Hyper-Active (10+)' 
        END AS activity_group,
        e.client_id,
        MIN(w.date_time) AS first_start_time
    FROM abtest.experiment e
    JOIN abtest.demo d ON e.client_id = d.client_id
    JOIN abtest.web w ON e.client_id = w.client_id
    WHERE w.process_step = 'start'
    GROUP BY 1, 2, 3
),
ValidConversions AS (
    -- Identify unique clients who converted AFTER their start time
    SELECT ss.client_id
    FROM SegmentStats ss
    JOIN abtest.web w ON ss.client_id = w.client_id
    WHERE w.process_step = 'confirm' 
      AND w.date_time > ss.first_start_time
    GROUP BY 1
),
AggregatedStats AS (
    -- Count N and X for each activity group and variation
    SELECT 
        ss.activity_group, 
        ss.variation,
        COUNT(DISTINCT ss.client_id) AS n,
        COUNT(DISTINCT vc.client_id) AS x
    FROM SegmentStats ss
    LEFT JOIN ValidConversions vc ON ss.client_id = vc.client_id
    GROUP BY 1, 2
),
Comparison AS (
    -- Pair Control and Test for Z-score calculation
    SELECT 
        c.activity_group,
        c.n AS ctrl_n, c.x AS ctrl_x, (c.x * 1.0 / NULLIF(c.n, 0)) AS ctrl_cr,
        t.n AS test_n, t.x AS test_x, (t.x * 1.0 / NULLIF(t.n, 0)) AS test_cr,
        ((c.x + t.x) * 1.0 / NULLIF(c.n + t.n, 0)) AS p_pooled
    FROM AggregatedStats c
    JOIN AggregatedStats t ON c.activity_group = t.activity_group
    WHERE c.variation = 'Control' AND t.variation = 'Test'
)
-- Step 5: Final calculation to see which group is driving the high Z-score
SELECT 
    activity_group,
    ctrl_n + test_n AS total_sample,
    ROUND(ctrl_cr * 100, 2) AS ctrl_cr_pct,
    ROUND(test_cr * 100, 2) AS test_cr_pct,
    ROUND(((test_cr - ctrl_cr) / NULLIF(ctrl_cr, 0)) * 100, 2) AS lift_pct,
    ROUND((test_cr - ctrl_cr) / 
        NULLIF(SQRT(p_pooled * (1.0 - p_pooled) * (1.0/NULLIF(ctrl_n,0) + 1.0/NULLIF(test_n,0))), 0), 4) AS segment_z_score
FROM Comparison
ORDER BY segment_z_score DESC;


-- Daily Conversion Rate
SELECT 
    DATE(w.date_time) AS activity_date,
    e.variation,
    COUNT(DISTINCT w.client_id) AS total_visitors,
    COUNT(DISTINCT CASE WHEN w.process_step = 'confirm' THEN w.client_id END) AS conversions,
    ROUND(
        COUNT(DISTINCT CASE WHEN w.process_step = 'confirm' THEN w.client_id END) / 
        COUNT(DISTINCT w.client_id) * 100, 2
    ) AS conversion_rate_pct
FROM web w
JOIN experiment e ON w.client_id = e.client_id
GROUP BY 1, 2
ORDER BY 1, 2;


-- daily cr with z score
WITH daily_stats AS (
    SELECT 
        DATE(w.date_time) AS activity_date,
        e.variation,
        COUNT(DISTINCT w.client_id) AS daily_visitors,
        COUNT(DISTINCT CASE WHEN w.process_step = 'confirm' THEN w.client_id END) AS daily_conversions
    FROM web w
    JOIN experiment e ON w.client_id = e.client_id
    GROUP BY 1, 2
),
cumulative_stats AS (
    SELECT 
        activity_date,
        variation,
        SUM(daily_visitors) OVER (PARTITION BY variation ORDER BY activity_date) AS n,
        SUM(daily_conversions) OVER (PARTITION BY variation ORDER BY activity_date) AS conv
    FROM daily_stats
),
pivoted AS (
    -- Align Control and Test stats on the same row
    SELECT 
        c.activity_date,
        c.n AS n_ctrl, 
        c.conv AS conv_ctrl, 
        (c.conv / NULLIF(c.n, 0)) AS p_ctrl,
        t.n AS n_test, 
        t.conv AS conv_test, 
        (t.conv / NULLIF(t.n, 0)) AS p_test
    FROM cumulative_stats c
    JOIN cumulative_stats t ON c.activity_date = t.activity_date
    WHERE c.variation = 'Control' AND t.variation = 'Test'
)
SELECT 
    activity_date,
    n_ctrl,
    n_test,
    ROUND(p_ctrl, 4) AS conv_rate_ctrl,
    ROUND(p_test, 4) AS conv_rate_test,
    ROUND(p_test - p_ctrl, 4) AS lift,
    -- Z-Score Formula: (p1 - p2) / sqrt(p_pooled * (1 - p_pooled) * (1/n1 + 1/n2))
    ROUND(
        (p_test - p_ctrl) / 
        SQRT(
            ((conv_ctrl + conv_test) / (n_ctrl + n_test)) * (1 - ((conv_ctrl + conv_test) / (n_ctrl + n_test))) * (1.0/n_ctrl + 1.0/n_test)
        ), 4
    ) AS z_score,
    -- Significance check (95% confidence)
    CASE 
        WHEN ABS((p_test - p_ctrl) / SQRT(((conv_ctrl + conv_test) / (n_ctrl + n_test)) * (1 - ((conv_ctrl + conv_test) / (n_ctrl + n_test))) * (1.0/n_ctrl + 1.0/n_test))) > 1.96 
        THEN 'Significant' 
        ELSE 'Not Significant' 
    END AS status
FROM pivoted;


-- spikes in cr
WITH daily_stats AS (
    SELECT 
        DATE(w.date_time) AS activity_date,
        e.variation,
        COUNT(DISTINCT w.client_id) AS daily_visitors,
        COUNT(DISTINCT CASE WHEN w.process_step = 'confirm' THEN w.client_id END) AS daily_conversions
    FROM web w
    JOIN experiment e ON w.client_id = e.client_id
    GROUP BY 1, 2
)
SELECT 
    activity_date,
    variation,
    -- Running total of visitors and conversions
    SUM(daily_visitors) OVER (PARTITION BY variation ORDER BY activity_date) AS cum_visitors,
    SUM(daily_conversions) OVER (PARTITION BY variation ORDER BY activity_date) AS cum_conversions,
    -- Running CR
    ROUND(
        SUM(daily_conversions) OVER (PARTITION BY variation ORDER BY activity_date) / 
        SUM(daily_visitors) OVER (PARTITION BY variation ORDER BY activity_date) * 100, 2
    ) AS cum_conversion_rate_pct
FROM daily_stats
ORDER BY activity_date, variation;


-- spikes in cr with z score
SELECT 
    DATE(w.date_time) AS activity_date,
    e.variation,
    COUNT(DISTINCT w.client_id) AS n,
    -- Conversion Rate (p)
    COUNT(DISTINCT CASE WHEN w.process_step = 'confirm' THEN w.client_id END) * 1.0 / COUNT(DISTINCT w.client_id) AS conv_rate,
    -- Standard Error: sqrt(p * (1-p) / n)
    SQRT(
        (COUNT(DISTINCT CASE WHEN w.process_step = 'confirm' THEN w.client_id END) * 1.0 / COUNT(DISTINCT w.client_id)) * (1 - (COUNT(DISTINCT CASE WHEN w.process_step = 'confirm' THEN w.client_id END) * 1.0 / COUNT(DISTINCT w.client_id))) / 
        COUNT(DISTINCT w.client_id)
    ) AS standard_error
FROM web w
JOIN experiment e ON w.client_id = e.client_id
GROUP BY 1, 2
ORDER BY 1, 2;


-- find days where traffic was off by over 25%
WITH daily_counts AS (
    SELECT 
        DATE(w.date_time) AS activity_date,
        COUNT(DISTINCT CASE WHEN e.variation = 'Control' THEN w.client_id END) AS control_visitors,
        COUNT(DISTINCT CASE WHEN e.variation = 'Test' THEN w.client_id END) AS test_visitors
    FROM web w
    JOIN experiment e ON w.client_id = e.client_id
    GROUP BY 1
)
SELECT 
    activity_date,
    control_visitors,
    test_visitors,
    ABS(test_visitors - control_visitors) / NULLIF(control_visitors, 0) AS pct_diff,
    CASE 
        WHEN ABS(test_visitors - control_visitors) / NULLIF(control_visitors, 0) > 0.25 
        THEN 'Skew too high' 
        ELSE 'Normal' 
    END AS data_quality_check
FROM daily_counts
ORDER BY activity_date;