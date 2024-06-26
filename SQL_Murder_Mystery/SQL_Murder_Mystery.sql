/* A crime has taken place and the detective needs your help. 
   The detective gave you the crime scene report, but you somehow lost it. 
   You vaguely remember that the crime was a murder that occurred sometime on Jan 15, 2018 and that it took place in SQL City
   Start by retrieving the corresponding crime scene report from the police department’s database. */

SELECT * 
FROM crime_scene_report
WHERE date = 20180115 AND city = "SQL City" AND type = "murder"

/* First witness lives on the last house on the street "Northwestern Dr".
   The second witness is called "Annabel" and lives on "Franklin Ave". */


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

/* First witness info:
   ID = 14887, name = "Morty Schapiro", license_id = 118009, ssn = 111564949

   Second witness info:
   ID = 16371, name = "Annabel Miller", license_id = 490173, ssn = 318771143

   Lets retrieve the interviews with these witnesses */

SELECT *
FROM interview
WHERE person_id IN (16371, 14887)

/* Got the following transcripts:
   I heard a gunshot and then saw a man run out. 
   He had a "Get Fit Now Gym" bag. The membership number on the bag started with "48Z". 
   Only gold members have those bags. The man got into a car with a plate that included "H42W".

   I saw the murder happen, and I recognized the killer from my gym when I was working out last week   on January the 9th. */

SELECT p.name, p.id
FROM get_fit_now_member as gfnm

INNER JOIN person as p ON p.id = gfnm.person_id
INNER JOIN drivers_license as dl ON dl.id = p.license_id

WHERE gfnm.id LIKE "48Z%" 
AND gfnm.membership_status = "gold"  
AND dl.plate_number LIKE "%H42W%"


/* This got me one name: Jeremy Bowers with 67318 as id. 
   When entered into the solution query I get the following text

   Congrats, you found the murderer! But wait, there's more... 
   If you think you're up for a challenge, try querying the interview transcript of the murderer to find the real villain behind this crime. */

SELECT *
FROM interview
WHERE person_id = '67318'

/* Got me the following interview transcript:

   I was hired by a woman with a lot of money. 
   I don't know her name but I know she's around 5'5" (65") or 5'7" (67"). 
   She has red hair and she drives a Tesla Model S. 
   I know that she attended the SQL Symphony Concert 3 times in December 2017. */

SELECT fec.person_id, COUNT(fec.person_id) as attendances, p.name, dl.hair_color, dl.gender, dl.height, dl.car_make, dl.car_model
FROM facebook_event_checkin AS fec

INNER JOIN person as p ON p.id = fec.person_id 
INNER JOIN drivers_license as dl on dl.id = p.license_id

WHERE fec.event_name = 'SQL Symphony Concert'
AND fec.date LIKE '201712%'
AND dl.car_make = 'Tesla'
AND dl.car_model = 'Model S'
AND dl.gender = 'female'
AND dl.hair_color = 'red'
AND (dl.height >= 65 AND dl.height <= 67)

GROUP BY person_id
HAVING attendances = 3

/* This got me the following name: Miranda Priestly. When inserted into the solution query I got the following text:
   
   Congrats, you found the brains behind the murder! 
   Everyone in SQL City hails you as the greatest SQL detective of all time. 
   Time to break out the champagne! */




