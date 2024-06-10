-- creating all tables

CREATE TABLE themes 
(
    id INT,
    name VARCHAR(512),
    parent_id INT
);

CREATE TABLE sets 
(
    set_num	VARCHAR(25),
    name	VARCHAR(100),
    year	INT,
    theme_id	INT,
    num_parts	INT
);

CREATE TABLE parts 
(
    part_num	VARCHAR(25),
    name	VARCHAR(250),
    part_cat_id	INT
);

CREATE OR REPLACE TABLE parts_categories 
(
    id	INT,
    name	VARCHAR(100)
);

CREATE OR REPLACE TABLE inventory_parts 
(
    inventory_id	INT,
    part_num	VARCHAR(25),
    color_id	INT,
    quantity	INT,
    is_spare	VARCHAR(1)
);

CREATE OR REPLACE TABLE inventories 
(
    id	INT,
    version	INT,
    set_num	VARCHAR(25)
);

CREATE TABLE colors 
(
    id	INT,
    name	VARCHAR(150),
    rgb	VARCHAR(10),
    is_trans	VARCHAR(1)
);

CREATE TABLE inventory_sets 
(
    inventory_id INT,
    set_num	VARCHAR(25),
    quantity INT
);

-- add primary and foreign keys

ALTER TABLE themes
ADD CONSTRAINT theme_key PRIMARY KEY (id);

ALTER TABLE sets
ADD CONSTRAINT set_key PRIMARY KEY (set_num);

ALTER TABLE sets
ADD CONSTRAINT theme_fk FOREIGN KEY (theme_id) REFERENCES themes(id);

ALTER TABLE parts 
ADD CONSTRAINT part_key PRIMARY KEY (part_num);

ALTER TABLE parts_categories
ADD CONSTRAINT parts_categories_key PRIMARY KEY (id);

ALTER TABLE parts
ADD CONSTRAINT parts_categories_fk FOREIGN KEY (part_cat_id) REFERENCES parts_categories(id);

ALTER TABLE inventory_parts
ADD CONSTRAINT inventory_parts_key PRIMARY KEY (inventory_id);

ALTER TABLE inventory_parts
ADD CONSTRAINT parts_fk FOREIGN KEY (part_num) REFERENCES parts(part_num);

ALTER TABLE inventories
ADD CONSTRAINT inventories_key PRIMARY KEY (id);

ALTER TABLE inventories
ADD CONSTRAINT set_num_fk FOREIGN KEY (set_num) REFERENCES sets(set_num);

ALTER TABLE colors
ADD CONSTRAINT colors_key PRIMARY KEY (id);

ALTER TABLE inventory_parts
ADD CONSTRAINT color_fk FOREIGN KEY (color_id) REFERENCES colors(id);

ALTER TABLE inventory_sets
ADD CONSTRAINT inventory_sets_key PRIMARY KEY (inventory_id);

ALTER TABLE inventory_sets
ADD CONSTRAINT set_num_fk FOREIGN KEY (set_num) REFERENCES sets(set_num);

ALTER TABLE inventory_sets
ADD CONSTRAINT inventories_fk FOREIGN KEY (inventory_id) REFERENCES inventories(id);

ALTER TABLE inventory_parts
ADD CONSTRAINT inventories_fk FOREIGN KEY (inventory_id) REFERENCES inventories(id);

--------------------------------------------------------------------------

CREATE OR REPLACE VIEW lego_analysis AS

-- I want to know the hierarchy of themes so I use a recursive CTE.

WITH RECURSIVE theme_view AS (
    SELECT 
      id
      ,name
      ,CAST(name AS varchar(50)) AS theme_hierarchy
    FROM 
      themes
    WHERE 
      parent_id IS NULL
     
UNION ALL
 
    SELECT 
      pt.id
      ,pt.name
      ,CAST(tv.theme_hierarchy || ' - ' || CAST(pt.name AS VARCHAR (510)) AS VARCHAR(510)) AS theme_hierarchy
    FROM 
      themes AS pt
    JOIN 
      theme_view AS tv
      ON pt.parent_id = tv.id
),

-- Then I create a CTE for identyfing all parts that are considered unique (thus only appearing in one set).

unique_parts AS (
    SELECT 
        part_num,
        COUNT(DISTINCT(i.set_num)) AS number_of_sets
    FROM 
        inventory_parts AS ip
    JOIN 
        inventories AS i
        ON ip.inventory_id = i.id
    GROUP BY 
        part_num 
    HAVING 
        number_of_sets = 1
),

-- I want to keep only unique parts in each set. 
-- So for example different colors of the same part number are now considered as the same part number. 
-- Also quantity does not matter, every part number is only counted once.

inventory_parts_deduplicated AS (
    SELECT 
        inventory_id
        ,part_num
        ,SUM(quantity)
    FROM 
        inventory_parts
    GROUP BY 
        inventory_id
        ,part_num
)

-- Then create the final statement. 
-- This is the statement that actually creates the table that is being stored in a view, which is afterwards accessed by Tableau to create a dashboard.

SELECT 
    s.set_num
    ,s.name AS set_name
    ,s.year
    ,tv.name AS theme_name
    ,tv.theme_hierarchy
    ,COUNT(DISTINCT(ip.part_num)) AS nr_of_unique_parts_in_set
    ,COUNT(DISTINCT(up.part_num)) AS nr_of_unique_parts_overall
    ,nr_of_unique_parts_overall / nr_of_unique_parts_in_set AS part_uniqueness_ratio
FROM 
    inventory_parts_deduplicated AS ip
LEFT JOIN
    unique_parts AS up
    ON ip.part_num = up.part_num
LEFT JOIN
    inventories AS i
    ON ip.inventory_id = i.id
LEFT JOIN 
    sets AS s
    ON i.set_num = s.set_num
LEFT JOIN
    theme_view AS tv
    ON s.theme_id = tv.id  
GROUP BY 
    s.set_num
    ,s.name
    ,s.year
    ,tv.name
    ,tv.theme_hierarchy;