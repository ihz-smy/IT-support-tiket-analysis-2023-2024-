# IT support ticket analysis (2023 - 2024)

## Project Background and Overview
This analysis examines the incident management event log over a 1 year period, including the case id, timestsmp, event, reporter, resolver, priority, issue type, report channel and customer satisfaction.

Each ticket is a case and can span over multiple events, the standard process flow is Ticket Created -> Ticket Assigned to Level 1 Support -> WIP - Level 1 Support -> Level 1 Escalates to Level 2 Support -> WIP - Level 2 Support -> Ticket Solved by Level 2 Support -> Customer Feedback Received -> Ticket Closed. However, there are many tickets than don't follow the standard process, including the need for customer feedback, the reassignments of ticket and reopened tickets. 

The KPIs we are investing are: customer satisfaction, process duration, number of tickets handled, number of errors (reassignments/loops) occured, errors rate. Recommendations will be used by customer service team to identify current issues in the process and better allocate resources for the future.

## Project Goals
1. Evaluate the performance of the customer support process
2. Identify patterns in the lower customer satisfaction cases or events
3. Provide recommendations for business growth through better service process improvements

## Data Cleaning and Extraction using SQL Server
1. Normalizes the 'Event' column for consistency and easy data labelling
```
UPDATE incident
SET Event = REPLACE(Event, 'escalates', 'assigned')
WHERE Event LIKE '%escalates%';

UPDATE incident
SET Event = REPLACE(Event, 'escalated', 'assigned')
WHERE Event LIKE '%escalated%';

UPDATE incident
SET Event = 
       SUBSTRING(Event, 
                PATINDEX('%assigned to level%', Event), 
                LEN('assigned to level') + 2)
WHERE Event LIKE '%assigned to level%';
```
This converts all the events name that involving 'assigning' a ticket to a specific level of support into the same format

2. Identifying the reassignment of ticket events/loops
```
WITH base AS (
	SELECT i1.Case_ID, i1.Event, i1.Timestamp, i2.Case_ID AS dup_ID, i2.Event AS dup_event, i2.Timestamp AS dup_time
	FROM incident i1
	LEFT JOIN incident i2 
	ON i1.Case_ID = i2.Case_ID
	AND i1.Event = i2.Event
	AND i1.Timestamp > i2.Timestamp),
base_v2 AS (
SELECT *, 
CASE
	WHEN dup_ID IS NOT NULL THEN 1
	ELSE 0
END AS duplicated
FROM base)
SELECT Case_ID, Event, Timestamp, SUM(duplicated) AS previous_visits,
CASE
	WHEN SUM(duplicated) > 0 THEN 1
	ELSE 0
END AS error
INTO incident_with_flag
FROM base_v2
GROUP BY Case_ID, Event, Timestamp
ORDER BY Case_ID, Timestamp;
```
This creates a new temporary table with the column of previous visits of each event of each ticket (1 event can be repeated multiple times in each ticket)
```
ALTER TABLE incident
ADD error int;
ALTER TABLE incident
ADD previous_visits int;

UPDATE incident
SET error = f.error, previous_visits = f.previous_visits
FROM incident i JOIN incident_with_flag f
ON i.Case_ID = f.Case_ID
AND i.Timestamp = f.Timestamp;
```
This joins the temporary table with the main table, flagging events with more than 0 previous visit as repeated, thus is an error

3. Calcuating the duration of each event
```
ALTER TABLE incident
ADD duration_seconds int;

WITH time AS (
SELECT *, LEAD(Timestamp) OVER (PARTITION BY Case_ID ORDER BY Timestamp) AS next_time
FROM incident)
UPDATE i
SET i.duration_seconds =
CASE
 WHEN t.next_time IS NULL THEN 0
 ELSE DATEDIFF(s, t.Timestamp, t.next_time)
END 
FROM incident i JOIN time t
ON i.Case_ID = t.Case_ID
AND i.Timestamp = t.Timestamp;
```
This creates a new column in the main table that calculates the duration of each event, and if it's the last event for that ticket, the duration is 0

4. Identifying if the Case received feedback from customers or not
```
let
    Source = incident,
    #"Removed Other Columns" = Table.SelectColumns(Source,{"Case_ID", "Event"}),
    #"Removed Duplicates" = Table.Distinct(#"Removed Other Columns"),
    #"Added Conditional Column" = Table.AddColumn(#"Removed Duplicates", "got_feedback", each if Text.Contains([Event], "feedback") then 1 else 0),
    #"Removed Columns" = Table.RemoveColumns(#"Added Conditional Column",{"Event"}),
    #"Grouped Rows" = Table.Group(#"Removed Columns", {"Case_ID"}, {{"receive_feedback", each List.Sum([got_feedback]), type number}})
in
    #"Grouped Rows"
```
This is done in Power BI, by keeping only the unique records of Case ID and Event, then idenitfying the 'Feedback received' event, grouping the rows by Case and SUM of that identify column. 

## Data structure overview
<img width="972" height="658" alt="image" src="https://github.com/user-attachments/assets/aca5faef-cfb4-4766-b27f-2a490dc651e4" />\
Each record in the main table 'incident' represents one event of each ticket, containing the following information: Case ID, Timestamp, Duration, Priority, Reporter, Resolver, Report channel, Previous visits, Errors, Customer satisfaction and Issue type.
Each record in the 'feedback table' represents a unque Case ID and whether that case received feedback from the customers


## Executive Summary
In the span of 1 year, 31K+ tickets were submitted, involving 242k+ events with an average satisfaction of 3.23. The number of tickets submitted remained steady over the period, at 2.6K+ cases per month. The most common Issue Type is Performance Issue and Bug at 8K+ and 6K+ cases. Bug is the Issue type that the customers were least satisfied about at the score of 2.8 while others were at 3.3+. Issues were mostly reported through website and email at 16K+ and 12K+ cases. There may be an imbalance in the workload as Emily reported 9K+ cases while others were only at 6K+. The same applied to the Resolver team, some handled 14K-28K+ events while others handled 1-2K+. Furthermore, those that handled the least events also got the least satisfaction score 2.3+ while the main team got 3.1-3.3. 

The average duration for each case is about 150 hours, with the average error rate 6.53%. On average, leve1 support, level 2 support and assigning created tickets took the longest time, at about 40 hours for each event. Bug was the issue ype that took the longest to solve, 160 hours

The issue type that generated the most errors is bug at 9K+ erros while others were at most 2K, consistantly at 700-800+ errors generated a month. Emily was the reporter that had the highest error rate at 7.1%+ while others were at 6.7%. James, Olivia, Ava, William had the highest error rate in the Resolvers team at 33-36%, the rest were at most 11%. Note that they also took the shortest amount of time for each case (11-18 hours), which may answers why their error rate was so high. 

Finally, the customer satisfaction score remained steady over the period, ranging at 3.21 - 3.26. James, Olivia, Ava, William also had the lowest satisfaction score at about 2.1 - 2.5 consistently. Whether the ticket received feedback from the customers was also important, all tickets that did not receive feedback got the score of 3 at most and the average score of only 1.98. 
## Insights deep dive
### Overview
<img width="1379" height="776" alt="image" src="https://github.com/user-attachments/assets/69e05461-e266-49e9-8700-de8c2fd88aaf" />\
The number of tickets submitted remained steady over the period, at 2.6K+ cases permonth, with the exception of February 2023 at 2.4K+ cases with the 100+ cases drop in Performance Issue. The most common Issue Type is Performance Issue and Bug at 8K+ and 6K+ cases. Bug is the Issue type that the customers were least satisfied about at the score of 2.8 while others were at 3.3+. 
<img width="1394" height="634" alt="image" src="https://github.com/user-attachments/assets/2b1adfcf-de04-471e-877d-9f502add5c5c" />\
Issues were mostly reported through website and email at 16K+ and 12K+ cases. 
<img width="1390" height="632" alt="image" src="https://github.com/user-attachments/assets/6a032582-13b2-4f16-bad3-680402866d5e" />\
There may be an imbalance in the workload as Emily reported 9K+ cases while others were only at 6K+.
<img width="1397" height="625" alt="image" src="https://github.com/user-attachments/assets/421b05b9-5abc-489b-a1a5-3ab68057b574" />\
The same applied to the Resolver team, Sam resolved 28K+ events, David 20K+ Emma 17K+, Michael 14K+, Sarah 8K+ while otheres were 1-2K+. Furthermore, those that handled the least events also got the least satisfaction score 2.3+ while the main team got 3.1-3.3. 
<img width="1396" height="629" alt="image" src="https://github.com/user-attachments/assets/dc07ca93-00bb-40ae-b043-1622bf75e084" />
### Duration and Errors
The average duration for each case is about 150 hours, with the average error rate 6.53%. On average, leve1 support, level 2 support and assigning created tickets took the longest time, at about 40 hours for each event, others events ranged at about 10-11 hours. Bug was the issue ype that took the longest to solve, 160 hours, others ate 140-150 hours. On average, each ticket took up 7-8 events. 
<img width="1382" height="769" alt="image" src="https://github.com/user-attachments/assets/684b6353-d5d2-4c40-bedb-f3d301ee9883" />
Hiogh priority cases took up abput 62 hours per case, which may be a bit too long for high priority and needed work, considering the average resolution time for the industry was about 82 hours in 2023 (source: https://www.jitbit.com/news/2266-average-customer-support-metrics-from-1000-companies/). And 258 hours to resolve low priority cases was definitely too long and shlould be improved immediately. 
<img width="1399" height="787" alt="image" src="https://github.com/user-attachments/assets/69b63def-5f81-488b-814b-102d1a4a64b7" />\
The issue type that generated the most errors is bug at 9K+ erros while others were at most 2K, consistantly at 700-800+ errors generated a month.

Emily was the reporter that had the highest error rate at 7.1%+ while others were at 6.7% despite the actual number of errors being the least of the team, 2.3K. 
<img width="1385" height="773" alt="image" src="https://github.com/user-attachments/assets/cace8eb3-3693-48cb-b8d6-83cc85835daa" />\
James, Olivia, Ava, William had the highest error rate in the Resolvers team at 33-36%, the rest were at most 11%. Note that they also took the shortest amount of time for each case (11-18 hours), which may answers why their error rate was so high, the rest took 25-42 hours for each case
<img width="1394" height="774" alt="image" src="https://github.com/user-attachments/assets/33a8ac40-a8bc-4c33-88d0-91c0e379a8f7" />
### Reopened cases
<img width="1392" height="776" alt="image" src="https://github.com/user-attachments/assets/44cdd250-eb98-42ba-97c2-06b515e16a92" />\
Bug was the issue type reopened the most, and Emily was the reporter with the most reopened cases, due to her having to manage the most cases. Interestingly, on average, Saturday was the peak for receiving reopened ticket, this may be due to the fact that users only had the time to thoroughly check the issue and report back on weekends. 

### Customer Satisfaction
The customer satisfaction score remained steady over the period, ranging at 3.21 - 3.26. James, Olivia, Ava, William also had the lowest satisfaction score at about 2.1 - 2.5 consistently. Whether the ticket received feedback from the customers was also important, all tickets that did not receive feedback got the score of 3 at most and the average score of only 1.98. 
<img width="1389" height="783" alt="image" src="https://github.com/user-attachments/assets/d868e021-fd5b-4a6a-9ca5-d253e12b0256" />\
<img width="1389" height="802" alt="image" src="https://github.com/user-attachments/assets/bf909c50-fe95-4278-b27b-a1f25ca3247c" />
## Recommendations
- Bug issues have lowest satisfaction (2.8)
  + Conduct Root Cause Analysis on Bug Tickets: Review common failure points, resolution notes, and customer comments to identify recurring problems.
  + Specialized Bug Resolution Team: Create a dedicated team for bug-related issues with technical expertise and extended resolution time targets.

- Tickets without feedback score only 1.98"
  + Feedback Incentivization: Encourage customers to leave feedback through small incentives (e.g., discount codes, loyalty points). This will improve data quality and satisfaction tracking.

- Certain agents (James, Olivia, Ava, William) have low satisfaction (2.1–2.5) and high error rates (33–36%):
  + Agent Coaching Program: Provide targeted training for agents with low satisfaction and high error rates. Pair them with mentors from high-performing teams
  + Encourage agents to prioritize accuracy over speed. Consider revising KPIs to reward low error rates and high satisfaction.

- Imbalanced workload (Emily: 9K+ cases vs. others: ~6K)
  + Redistribute Workload: Use ticket assignment algorithms to balance load across reporters and resolvers. Avoid overloading top performers like Emily






