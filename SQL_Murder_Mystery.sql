-- A crime has taken place and the detective needs your help. 
-- The detective gave you the crime scene report, but you somehow lost it. 
-- You vaguely remember that the crime was a murder that occurred sometime on Jan 15, 2018 and that it took place in SQL City
-- Start by retrieving the corresponding crime scene report from the police department’s database.

SELECT * 
FROM crime_scene_report
WHERE date = 20180115 AND city = "SQL City" AND type = "murder"

-- First witness lives on the last house on the street "Northwestern Dr".
-- The second witness is called "Annabel" and lives on "Franklin Ave"


-- First witness
SELECT *
FROM person
WHERE address_street_name = "Northwestern Dr" 
ORDER BY address_number DESC
LIMIT 1;

--Second witness
SELECT *
FROM person
WHERE address_street_name = "Franklin Ave"
AND LOWER(name) LIKE "%annabel%";

-- First witness info:
-- ID = 14887, name = "Morty Schapiro", license_id = 118009, ssn = 111564949

-- Second witness info:
-- ID = 16371, name = "Annabel Miller", license_id = 490173, ssn = 318771143

-- Lets retrieve the interviews with these witnesses

SELECT *
FROM interview
WHERE person_id IN (16371, 14887)

-- Got the following transcripts:
-- I heard a gunshot and then saw a man run out. 
-- He had a "Get Fit Now Gym" bag. The membership number on the bag started with "48Z". 
-- Only gold members have those bags. The man got into a car with a plate that included "H42W".

-- I saw the murder happen, and I recognized the killer from my gym when I was working out last week on January the 9th.

SELECT *
FROM get_fit_now_member
WHERE id LIKE "48Z%" AND membership_status = "gold"

-- This got me two members: "Joe Germuska" and "Jeremy Bowers"

SELECT *
FROM get_fit_now_check_in
WHERE check_in_date = 20180109
