use seafoodkart

--1. User Metrics
-- Count the number of unique users
SELECT COUNT(DISTINCT user_id) AS unique_users
FROM Users;

-- Average number of visits per user
SELECT AVG(visit_count) AS avg_visits_per_user
FROM (
    SELECT u.user_id, COUNT(e.visit_id) AS visit_count
    FROM Events e
    JOIN Users u ON e.cookie_id = u.cookie_id
    GROUP BY u.user_id
) AS user_visits;

--2.Visit Analysis
--a. Distribution of visits over time

SELECT CAST(event_time AS DATE) AS visit_date, COUNT(DISTINCT visit_id) AS visit_count
FROM Events
GROUP BY CAST(event_time AS DATE)
ORDER BY visit_date;

--b. Peak visit times and days

SELECT DATEPART(HOUR, event_time) AS visit_hour, COUNT(DISTINCT visit_id) AS visit_count
FROM Events
GROUP BY DATEPART(HOUR, event_time)
ORDER BY visit_count DESC;


--3. Event Analysis
--a. Count different event types

SELECT e.event_name, COUNT(ev.event_type) AS event_count
FROM Events ev
JOIN Event_Identifier e ON ev.event_type = e.event_type
GROUP BY e.event_name;

--b. Analyze the sequence of events

SELECT visit_id, sequence_number, event_name
FROM Events ev
JOIN Event_Identifier e ON ev.event_type = e.event_type
ORDER BY visit_id, sequence_number;


--4. Page Performance
--a. Most and least visited pages

SELECT p.page_name, COUNT(e.event_type) AS visit_count
FROM Events e
JOIN page_heirarchy p ON e.page_id = p.page_id
GROUP BY p.page_name
ORDER BY visit_count DESC;

--b. Time spent on each page

SELECT p.page_name, AVG(DATEDIFF(SECOND, e1.event_time, e2.event_time)) AS avg_time_spent
FROM Events e1
JOIN Events e2 ON e1.visit_id = e2.visit_id AND e1.sequence_number = e2.sequence_number - 1
JOIN page_heirarchy p ON e1.page_id = p.page_id
GROUP BY p.page_name;

--5. Product Performance
--a. Most and least popular products

SELECT p.product_id, p.product_category, COUNT(e.event_type) AS view_count
FROM Events e
JOIN page_heirarchy p ON e.page_id = p.page_id
WHERE e.event_type = 1  -- Use the correct integer value for 'page_view'
GROUP BY p.product_id, p.product_category
ORDER BY view_count DESC;

--b.Conversion rates from product page views to purchases

SELECT p.product_id, p.page_name, 
       COALESCE(COUNT(CASE WHEN e.event_type = '2' THEN 1 END) * 1.0 / NULLIF(COUNT(CASE WHEN e.event_type = '1' THEN 1 END), 0), 0) AS conversion_rate
FROM Events e
JOIN page_heirarchy p ON e.page_id = p.page_id
GROUP BY p.product_id, p.page_name;


--6. Campaign Analysis
--a. Campaign performance

SELECT c.campaign_name, 
       COUNT(DISTINCT e.visit_id) AS visit_count,
       COUNT(CASE WHEN e.event_type = 4 THEN 1 END) AS click_count,
       COUNT(CASE WHEN e.event_type = 3 THEN 1 END) AS purchase_count
FROM Events e
JOIN Campaign_Identifier c 
    ON e.event_time BETWEEN c.start_date AND c.end_date
GROUP BY c.campaign_name;

--b.Visit-level campaign analysis

SELECT e.visit_id, u.user_id, MIN(e.event_time) AS visit_start_time,
       COUNT(CASE WHEN e.event_type = 1 THEN 1 END) AS page_views,
       COUNT(CASE WHEN e.event_type = 2 THEN 1 END) AS cart_adds,
       MAX(CASE WHEN e.event_type = 3 THEN 1 ELSE 0 END) AS purchase_flag,
       c.campaign_name,
       COUNT(CASE WHEN e.event_type = 4 THEN 1 END) AS impression_count,
       COUNT(CASE WHEN e.event_type = 5 THEN 1 END) AS click_count,
       STUFF(
           (SELECT ', ' + p.page_name
            FROM Events e2
            JOIN page_heirarchy p ON e2.page_id = p.page_id
            WHERE e2.visit_id = e.visit_id AND e2.event_type = 2
            FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, ''
       ) AS cart_products
FROM Events e
JOIN Users u ON e.cookie_id = u.cookie_id
LEFT JOIN Campaign_Identifier c 
    ON e.event_time BETWEEN c.start_date AND c.end_date
GROUP BY e.visit_id, u.user_id, c.campaign_name;
