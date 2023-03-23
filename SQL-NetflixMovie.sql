CREATE DATABASE NetflixMovie

SELECT*FROM credits
WHERE person_id like 0

SELECT*FROM titles
WHERE Id is null

--Checking if there any duplication value in Person_ID in credits table
SELECT Person_ID, COUNT(Person_ID) AS CheckDup FROM credits
GROUP BY person_id
HAVING COUNT(Person_ID) >1

-->> Yes, Person_ID has duplicate values

--Checking if there any duplication value in id in titles table

SELECT ID, COUNT(ID) AS CheckDup FROM titles
GROUP BY ID
HAVING COUNT(ID) >1

-->> No duplicate values in ID
-- Create Primary key as ID

ALTER TABLE titles
ALTER COLUMN ID nvarchar(50) NOT NULL

ALTER TABLE titles
ADD CONSTRAINT PK_titles PRIMARY KEY (ID )

-- Create foreign key in credits table

ALTER TABLE credits
ADD CONSTRAINT FK_credits FOREIGN KEY(ID) REFERENCES titles(ID)

SELECT DISTINCT type FROM titles

--Count how many gener of each movie, then create view for viz later
CREATE VIEW MovieGenres AS
(	SELECT ID,title,type,release_year,
	LEN(genres)-LEN(REPLACE(genres,',',''))+1 Genres_Count
	FROM titles
)

-- Ranking IMDB,TMDB score in all time and each year
CREATE VIEW MovieRanking AS
(
SELECT Sub1.*,Sub2.tmdb_score
FROM
	(SELECT id,title,release_year,imdb_score,
	DENSE_RANK() OVER(PARTITION BY release_year ORDER BY tmdb_score) TMDBScoreRanking_Yearly,
	DENSE_RANK () OVER(ORDER BY tmdb_score) TMDBScoreRanking_AllTime
	FROM titles
	WHERE imdb_score IS NOT NULL) Sub1

INNER JOIN

	(SELECT id,title,release_year,tmdb_score,
	DENSE_RANK() OVER(PARTITION BY release_year ORDER BY tmdb_score) TMDBScoreRanking_Yearly,
	DENSE_RANK () OVER(ORDER BY tmdb_score) TMDBScoreRanking_AllTime
	FROM titles
	WHERE tmdb_score IS NOT NULL) Sub2

ON Sub1.id = Sub2.id
)


-- Ranking runtime movies in all time and each year
CREATE VIEW MovieDuration AS
(
	SELECT id,title,release_year,runtime,
	DENSE_RANK() OVER(PARTITION BY release_year ORDER BY runtime) Duration_Yearly,
	DENSE_RANK () OVER(ORDER BY runtime) Duration_AllTime
	FROM titles
	WHERE runtime IS NOT NULL
	AND   runtime <>0
)

-- Which year has the most movie/tv show

CREATE VIEW MovieCount AS
(
	SELECT type,release_year,COUNT(id) Movie_Count
	FROM titles
	GROUP BY type,release_year
)

--Define genres of each movie
ALTER VIEW MovieAllType AS
(
	SELECT id,title,type,release_year,REPLACE(value,'''','') Genre FROM 
	(
		SELECT *
		FROM titles
		CROSS APPLY STRING_SPLIT(REPLACE(REPLACE(Genres,']',''),'[',''), ',')
	) Sub1
)

SELECT * FROM MovieAllType

--Grouping genres by year by type

SELECT release_year,type, Genre, COUNT(id) Genre_count
FROM MovieAllType
GROUP BY release_year,type,Genre
HAVING Genre IS NOT NULL

--Creating time interval
SELECT id,title,type,release_year,
		CASE 
		WHEN release_year<=1990 THEN 'Before 1990'
		WHEN release_year<2000 THEN 'From 1990-2000'
		WHEN release_year<=2010 THEN 'From 2000-2010'
		ELSE 'After 2010'
		END
		AS Period
FROM titles
ORDER BY release_year


--Calculating Quintile of imdb_score and tmdb_score

CREATE VIEW QuintileCategory AS
(
SELECT Sub1.*,Sub2.tmdb_score,Sub2.TMDB_QuintileCategory
FROM
(
	SELECT ID,title,release_year,imdb_score,
		NTILE(5) OVER(PARTITION BY release_year ORDER BY imdb_score) imdb_score_Quintile,
		CASE
		   WHEN NTILE(5) OVER(PARTITION BY release_year ORDER BY imdb_score) = 1 THEN 'Top Quintile'
		   WHEN NTILE(5) OVER(PARTITION BY release_year ORDER BY imdb_score) = 2 THEN 'Second Quintile'
		   WHEN NTILE(5) OVER(PARTITION BY release_year ORDER BY imdb_score) = 3 THEN 'Third Quintile'
		   WHEN NTILE(5) OVER(PARTITION BY release_year ORDER BY imdb_score) = 4 THEN 'Four Quintile'
		   ELSE 'Bottom Quintile'
		END 
		AS IMDB_QuintileCategory
		FROM titles
) Sub1

INNER JOIN
(
	SELECT ID,title,release_year,tmdb_score,
		NTILE(5) OVER(PARTITION BY release_year ORDER BY tmdb_score) tmdb_score_Quintile,
		CASE
		   WHEN NTILE(5) OVER(PARTITION BY release_year ORDER BY tmdb_score) = 1 THEN 'Top Quintile'
		   WHEN NTILE(5) OVER(PARTITION BY release_year ORDER BY tmdb_score) = 2 THEN 'Second Quintile'
		   WHEN NTILE(5) OVER(PARTITION BY release_year ORDER BY tmdb_score) = 3 THEN 'Third Quintile'
		   WHEN NTILE(5) OVER(PARTITION BY release_year ORDER BY tmdb_score) = 4 THEN 'Four Quintile'
		   ELSE 'Bottom Quintile'
		END 
		AS TMDB_QuintileCategory
		FROM titles
) Sub2
ON Sub1.id=Sub2.id
AND Sub1.release_year=Sub2.release_year
)

SELECT * FROM QuintileCategory

SELECT id,title,type,release_year,age_certification,runtime
FROM titles

ALTER VIEW MovieAllType AS
(
	SELECT id,title,type,release_year,TRIM(REPLACE(value,'''','')) Genre FROM 
	(
		SELECT *
		FROM titles
		CROSS APPLY STRING_SPLIT(REPLACE(REPLACE(Genres,']',''),'[',''), ',')
		WHERE genres is not null 
		OR genres<>0 
	) Sub1
)
USE NetflixMovie
GO

-- Conver score from movierank to float
ALTER VIEW MovieRanking AS
(
SELECT Sub1.*,Sub2.tmdb_score,Sub2.TMDBScoreRanking_AllTime,Sub2.TMDBScoreRanking_Yearly
FROM
	(SELECT id,title,release_year,CAST(imdb_score AS Float) imdb_score,
	DENSE_RANK() OVER(PARTITION BY release_year ORDER BY imdb_score) IMDBScoreRanking_Yearly,
	DENSE_RANK () OVER(ORDER BY imdb_score) IMDBScoreRanking_AllTime
	FROM titles
	WHERE imdb_score IS NOT NULL) Sub1

INNER JOIN

	(SELECT id,title,release_year,CAST(tmdb_score AS FLOAT) tmdb_score,
	DENSE_RANK() OVER(PARTITION BY release_year ORDER BY tmdb_score) TMDBScoreRanking_Yearly,
	DENSE_RANK () OVER(ORDER BY tmdb_score) TMDBScoreRanking_AllTime
	FROM titles
	WHERE tmdb_score IS NOT NULL) Sub2

ON Sub1.id = Sub2.id
)

SELECT M.*,T.type,CONCAT(M.title,'-',M.release_year) FilmYear
FROM MovieRanking M
INNER JOIN titles T
ON M.id=T.id

SELECT*FROM QuintileCategory
USE NetflixMovie
GO

SELECT M.*,T.type,CONCAT(M.title,'-',M.release_year) FilmYear
FROM MovieRanking M
INNER JOIN titles T
ON M.id=T.id
WHERE M.id = 'tm1000166'


USE NetflixMovie
GO
SELECT * FROM MOVIEALLTYPE
WHERE Genre is null

-- Creating View for Movie Rev 
ALTER VIEW MovieRev AS
(
	SELECT M.*,CONCAT(M.Movie,'-',M.Year) MovieName,T.type,T.age_certification,T.runtime,T.production_countries,T.id,T.imdb_score,T.tmdb_score,T.imdb_votes,T.tmdb_popularity FROM Movie_rev M
	LEFT JOIN titles T
	ON M.Movie = T.title
	AND M.Year = T.release_year
)





