--Create table with columns as they appear on csv file headers
Create table if not exists player_details 
(P_ID int PRIMARY KEY,
PName VARCHAR (50),
L1_status int,
L2_status int,
L1_code VARCHAR (30),
L2_code VARCHAR (30)
)
---ALTER table player_details ALTER COLUMN L2_code TYPE VARCHAR (30);
;---drop table level_details;
Create table if not exists level_details
(
	P_ID int ,
	Dev_ID VARCHAR (20),
	start_time timestamp,
	Stages_crossed int,
	level int,
	Difficulty varchar (10),
	Kill_count int,
	Headshots_count int,
	Score int,
	Lives_Earned int,
	 FOREIGN KEY(P_ID) 
        REFERENCES player_details (P_ID)
	
)
;
ALTER TABLE level_details rename column difficulty_l to Difficulty_level;
---Inserted the details using the import functionality 
-- Q1.Extract P_ID,Dev_ID,PName and Difficulty_level of all players 
-- at level 0

	select P_ID, Dev_ID,PName,Difficulty_level,Level
	FROM level_details
	JOIN player_details using (P_ID)
	WHERE LEVEL = 0;

-- Q2) Find Level1_code wise Avg_Kill_Count where lives_earned is 2 and atleast
--    3 stages are crossed
	
	with level_query as (select  P_ID ,l1_code,kill_count
	FROM level_details
	JOIN player_details using (P_ID)
	where lives_earned = 2 and stages_crossed >= 3)
	select l1_code, round( avg(kill_count),2) from level_query
	group by l1_code
;
   
-- Q3) Find the total number of stages crossed at each diffuculty level
-- where for Level2 with players use zm_series devices. Arrange the result
-- in decsreasing order of total number of stages crossed.

	select difficulty_level, sum(stages_crossed) as "Total stages_crossed"
	from level_details
	where level=2 and dev_id like 'zm%'
	group by difficulty_level
	order by Sum(stages_crossed) desc;;

-- Q4) Extract P_ID and the total number of unique dates for those players 
-- who have played games on multiple days.
SELECT DISTINCT P_ID, COUNT(start_time ) AS unique_dates_count
FROM level_details
	JOIN player_details using (P_ID)
GROUP BY P_ID
HAVING COUNT(DISTINCT start_time ) > 1;
	
		
-- Q5) Find P_ID and level wise sum of kill_counts where kill_count
-- is greater than avg kill count for the Medium difficulty.

	with level_query as (select  P_ID ,l1_code, kill_count
	FROM level_details
	JOIN player_details using (P_ID)
	where kill_count > (select round(avg(kill_count),2) 
						from level_details where difficulty_level = 'Medium')
	)
	select l1_code, sum(kill_count) from level_query
	group by l1_code
;
-- Q6)Find Level and its corresponding Level code wise sum of lives earned 
-- excluding level 0. Arrange in ascending order of level.
		select level,sum(lives_earned)lives_earned,l1_code as level_code from level_details
		join player_details using (p_id) 
		where level !=0
		group by level,l1_code
		union		
		select level,sum(lives_earned) lives_earned,l2_code as level_code from level_details
		join player_details using (p_id) 
		where level !=0
		group by level,l2_code
		order by lives_earned;
-- Q7) Find Top 3 score based on each dev_id and Rank them in increasing order
-- using Row_Number. Display difficulty as well. 
with score_rank as (SELECT
difficulty_level,
	score,
	Row_number() OVER (
		partition by dev_id
		ORDER BY score DESC
	) score_rank
FROM level_details)
select * from score_rank 
where score_rank <= 3
order by score_rank asc
;
-- Q8) Find first_login datetime for each device id

	with login as (select start_time, dev_id,
				   row_number () over (partition by dev_id
									  order by start_time asc) as login_order
				   from level_details)
	select * from login where login_order = 1
				   

-- Q9) Find Top 5 score based on each difficulty level and Rank them in 
-- increasing order using Rank. Display dev_id as well.
	with difficulty_rank as (SELECT
	difficulty_level,
		dev_id,
		RANK() OVER (
			partition by difficulty_level
			ORDER BY score ASC
		) rank
	FROM level_details)
	select * from difficulty_rank
	where rank <= 5
	order by rank asc;
-- Q10) Find the device ID that is first logged in(based on start_datetime) 
-- for each player(p_id). Output should contain player id, device id and 
-- first login datetime.
		--Solution---
	with login as (select start_time, dev_id, p_id,
				   row_number () over (partition by dev_id
									  order by start_time asc) as first_login
				   from level_details)
	select * from login where first_login = 1
				   	
-- Q11) For each player and date, how many kill_count played so far by the player. That is, the total number of games played 
-- by the player until that date.
-- a) window function
	SELECT P_ID,
       start_time,
       kill_count,
       SUM(kill_count) OVER (PARTITION BY P_ID ORDER BY start_time 
							 rows between unbounded preceding and current row) AS cumulative_kill_count
	FROM level_details;
-- b) without window function
	SELECT ld.P_ID,
       ld.start_time,
       ld.kill_count,
       (SELECT SUM(kill_count)
        FROM level_details ld2
        WHERE ld2.P_ID = ld.P_ID AND ld2.start_time <= ld.start_time) AS cumulative_kill_count
	FROM level_details ld;
-- Q12) Find the cumulative sum of stages crossed over a start_time 
	SELECT P_ID,
       start_time,
       stages_crossed,
       SUM(stages_crossed) OVER (PARTITION BY p_id order by start_time
							 rows between unbounded preceding and current row)
							 AS cumulative_stages_crossed
	FROM level_details;
-- Q13) Find the cumulative sum of an stages crossed over a start_datetime 
-- for each player id but exclude the most recent start_datetime
		--- alternative--
SELECT t1.P_ID, t1.start_time, t1.stages_crossed,
       SUM(t2.stages_crossed) AS Cumulative_Stages_Crossed
FROM level_details t1
JOIN level_details t2
    ON t1.P_ID = t2.P_ID
    AND t1.start_time >= t2.start_time
WHERE t1.start_time < (SELECT MAX(start_time) FROM level_details WHERE P_ID = t1.P_ID)
GROUP BY t1.P_ID, t1.start_time, t1.stages_crossed
ORDER BY t1.P_ID, t1.start_time;


-- Q14) Extract top 3 highest sum of score for each device id and the corresponding player_id
with score_rank as(select p_id,
	dev_id, 
	sum(score),  
	rank () over ( partition by dev_id order by sum(score) desc) as rank_score
from level_details
 GROUP BY Dev_ID, P_ID)
 select * from score_rank where rank_score <=3 
 
-- Q15) Find players who scored more than 50% of the avg score scored by sum of 
-- scores for each player_id
	--alternative----
with PlayerTotalScore as (
    select 
		P_ID, 
		sum(Score) as total_score
    from level_details
    group by P_ID
)
select 
	P_ID
from PlayerTotalScore
where total_score > (select avg(total_score) * 0.5 from PlayerTotalScore);
		
-- Q16) Create a stored procedure to find top n headshots_count based on each dev_id and Rank them in increasing order
-- using Row_Number. Display difficulty as well.

create or replace procedure headshots_count (n int)
language plpgsql    
as $$
declare 
difficulty varchar;
headshot_count int;
BEGIN

	with difficulty_rank as (SELECT
	difficulty_level,
	headshots_count,
		Row_number() OVER (
			partition by dev_id
			
		) rownumber
	FROM level_details)
	select difficulty_level,headshots_count into difficulty, headshot_count from difficulty_rank
	where rownumber <= n
	order by headshots_count asc;

end;$$;

call headshots_count(5);
-- Q17) Create a function to return sum of Score for a given player_id.

create or replace function sum_score(
  player_id int) 
  returns int
language plpgsql
as $$
declare
sum_score integer;
begin
  
  select sum(score) into sum_score from level_details where p_id =player_id;
  return sum_score;

end;$$;
select * from sum_score(590)

