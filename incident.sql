
--UPDATE incident
--SET Event = REPLACE(Event, 'escalates', 'assigned')
--WHERE Event LIKE '%escalates%';

--UPDATE incident
--SET Event = REPLACE(Event, 'escalated', 'assigned')
--WHERE Event LIKE '%escalated%';

--UPDATE incident
--SET Event = 
--       SUBSTRING(Event, 
--                PATINDEX('%assigned to level%', Event), 
--                LEN('assigned to level') + 2)
--WHERE Event LIKE '%assigned to level%';

--WITH base AS (
--	SELECT i1.Case_ID, i1.Event, i1.Timestamp, i2.Case_ID AS dup_ID, i2.Event AS dup_event, i2.Timestamp AS dup_time
--	FROM incident i1
--	LEFT JOIN incident i2 
--	ON i1.Case_ID = i2.Case_ID
--	AND i1.Event = i2.Event
--	AND i1.Timestamp > i2.Timestamp),
--base_v2 AS (
--SELECT *, 
--CASE
--	WHEN dup_ID IS NOT NULL THEN 1
--	ELSE 0
--END AS duplicated
--FROM base)
--SELECT Case_ID, Event, Timestamp, SUM(duplicated) AS previous_visits,
--CASE
--	WHEN SUM(duplicated) > 0 THEN 1
--	ELSE 0
--END AS error
--INTO incident_with_flag
--FROM base_v2
--GROUP BY Case_ID, Event, Timestamp
--ORDER BY Case_ID, Timestamp;

--ALTER TABLE incident
--ADD error int;
--ALTER TABLE incident
--ADD previous_visits int;

--UPDATE incident
--SET error = f.error, previous_visits = f.previous_visits
--FROM incident i JOIN incident_with_flag f
--ON i.Case_ID = f.Case_ID
--AND i.Timestamp = f.Timestamp;

--ALTER TABLE incident
--ADD duration_seconds int;

--WITH time AS (
--SELECT *, LEAD(Timestamp) OVER (PARTITION BY Case_ID ORDER BY Timestamp) AS next_time
--FROM incident)
--UPDATE i
--SET i.duration_seconds =
--CASE
-- WHEN t.next_time IS NULL THEN 0
-- ELSE DATEDIFF(s, t.Timestamp, t.next_time)
--END 
--FROM incident i JOIN time t
--ON i.Case_ID = t.Case_ID
--AND i.Timestamp = t.Timestamp;