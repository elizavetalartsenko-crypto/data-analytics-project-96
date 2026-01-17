WITH last_paid_click AS (
    SELECT
        s.visitor_id,
        DATE(s.visit_date) AS visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        ROW_NUMBER() OVER (
            PARTITION BY l.lead_id
            ORDER BY l.created_at ASC  -- take the first lead creation instead of last session
        ) AS rn
    FROM sessions s
    LEFT JOIN leads l
        ON s.visitor_id = l.visitor_id
       AND s.visit_date <= l.created_at
    WHERE s.medium IN ('cpc','cpm','cpa','youtube','cpp','tg','social')
)
SELECT
    lpc.visit_date,
    COUNT(DISTINCT lpc.visitor_id) AS visitors_count,
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    COUNT(DISTINCT lpc.lead_id) AS leads_count,
    COUNT(DISTINCT CASE 
        WHEN lpc.closing_reason = 'Успешно реализовано' OR lpc.status_id = 142
        THEN lpc.lead_id
    END) AS purchases_count,
    SUM(CASE 
        WHEN lpc.closing_reason = 'Успешно реализовано' OR lpc.status_id = 142
        THEN lpc.amount
        ELSE 0
    END) AS revenue,
    COALESCE(SUM(DISTINCT vk.daily_spent),0) + COALESCE(SUM(DISTINCT ya.daily_spent),0) AS total_cost
FROM last_paid_click lpc
LEFT JOIN vk_ads vk
    ON lpc.utm_source = vk.utm_source
   AND lpc.utm_medium = vk.utm_medium
   AND lpc.utm_campaign = vk.utm_campaign
   AND DATE(lpc.visit_date) = vk.campaign_date
LEFT JOIN ya_ads ya
    ON lpc.utm_source = ya.utm_source
   AND lpc.utm_medium = ya.utm_medium
   AND lpc.utm_campaign = ya.utm_campaign
   AND DATE(lpc.visit_date) = ya.campaign_date
WHERE lpc.rn = 1 OR lpc.lead_id IS NULL
GROUP BY lpc.visit_date, lpc.utm_source, lpc.utm_medium, lpc.utm_campaign
ORDER BY
    lpc.visit_date ASC,
    visitors_count DESC,
    lpc.utm_source ASC,
    lpc.utm_medium ASC,
    lpc.utm_campaign ASC,
    revenue DESC NULLS last
limit 15;
