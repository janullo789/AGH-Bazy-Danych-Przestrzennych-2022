CREATE SCHEMA cw3;

-- 1. Znajdź budynki, które zostały wybudowane lub wyremontowane na przestrzeni roku (zmiana pomiędzy 2018 a 2019).

SELECT * FROM cw3.t2018_kar_buildings ORDER BY polygon_id;
SELECT * FROM cw3.t2019_kar_buildings ORDER BY polygon_id;

SELECT b.*
FROM cw3.t2018_kar_buildings a RIGHT JOIN cw3.t2019_kar_buildings b
ON a.polygon_id = b.polygon_id
WHERE a.height != b.height
		OR NOT(ST_Equals(a.geom, b.geom))
		OR a.polygon_id is null;


-- 2. Znajdź ile nowych POI pojawiło się w promieniu 500 m od wyremontowanych lub wybudowanych budynków,
--	które znalezione zostały w zadaniu 1. Policz je wg ich kategorii.

SELECT b.* INTO TEMP TABLE tempNewBul
FROM cw3.t2018_kar_buildings a RIGHT JOIN cw3.t2019_kar_buildings b
ON a.polygon_id = b.polygon_id
WHERE a.height != b.height
		OR NOT(ST_Equals(a.geom, b.geom))
		OR a.polygon_id is null; --stworzenie tabeli tymczasowej

SELECT * FROM tempNewBul;

SELECT * FROM cw3.t2018_kar_poi_table;
SELECT * FROM cw3.t2019_kar_poi_table;

SELECT DISTINCT b.*
FROM cw3.t2018_kar_poi_table a RIGHT JOIN cw3.t2019_kar_poi_table b
ON a.poi_id = b.poi_id
WHERE a.poi_id is null; -- wyswietlanie

SELECT DISTINCT b.* INTO TEMP TABLE tempNewPoi
FROM cw3.t2018_kar_poi_table a RIGHT JOIN cw3.t2019_kar_poi_table b
ON a.poi_id = b.poi_id
WHERE a.poi_id is null;

SELECT p.type, COUNT (DISTINCT (p.*))
FROM tempNewPoi p, tempNewBul b
WHERE ST_DWithin(p.geom, b.geom, 0.0045)
GROUP BY p.type;

-- 3. Utwórz nową tabelę o nazwie ‘streets_reprojected’, która zawierać będzie dane z tabeli T2019_KAR_STREETS
--	przetransformowane do układu współrzędnych DHDN.Berlin/Cassini.

SELECT * FROM cw3.T2019_KAR_STREETS;

SELECT gid, link_id, st_name, ref_in_id, nref_in_id, func_class, speed_cat, fr_speed_l, to_speed_l, dir_travel,
		ST_TRANSFORM(geom, 3068)
INTO TABLE cw3.streets_reprojected
FROM cw3.T2019_KAR_STREETS;

SELECT *, ST_SRID(st_transform) FROM cw3.streets_reprojected;

-- 4. Stwórz tabelę o nazwie ‘input_points’ i dodaj do niej dwa rekordy o geometrii punktowej.
--	Użyj następujących współrzędnych: X1 = 8.36093 Y1 = 49.03174, X2 =8.39876 Y2 = 40.00644

CREATE TABLE cw3.input_points(
	id INT,
	geom GEOMETRY
);


INSERT INTO cw3.input_points VALUES (1, ST_GeomFromText('POINT(8.36093 49.03174)', 4326));
INSERT INTO cw3.input_points VALUES (2, ST_GeomFromText('POINT(8.39876 49.00644)', 4326));

SELECT * FROM cw3.input_points;

-- 5. Zaktualizuj dane w tabeli ‘input_points’ tak, aby punkty te były w układzie współrzędnych DHDN.Berlin/Cassini.
--	Wyświetl współrzędne za pomocą funkcji ST_AsText().

UPDATE cw3.input_points SET geom = ST_TRANSFORM(geom, 3068);

SELECT *, ST_AsText(geom) FROM cw3.input_points;

-- 6. Znajdź wszystkie skrzyżowania, które znajdują się w odległości 200 m od linii zbudowanej z punktów w tabeli ‘input_points’.
--	Wykorzystaj tabelę T2019_STREET_NODE. Dokonaj reprojekcji geometrii, aby była zgodna z resztą tabel.

SELECT * FROM cw3.T2019_KAR_STREET_NODE;

--UPDATE cw3.T2019_KAR_STREET_NODE SET geom = ST_TRANSFORM(geom, 3068); -- nie działa

UPDATE cw3.input_points SET geom = ST_TRANSFORM(geom, 4326);

SELECT ST_SRID(geom) FROM cw3.t2019_kar_street_node;
SELECT ST_SRID(geom) FROM cw3.input_points;

SELECT DISTINCT str.* FROM cw3.t2019_kar_street_node str
WHERE ST_DWithin(
	(SELECT ST_MakeLine(geom) FROM cw3.input_points)
	, str.geom, 0.000018);

-- 7. Policz jak wiele sklepów sportowych (‘Sporting Goods Store’ - tabela POIs) znajduje się w odległości 300 m od parków (LAND_USE_A).

SELECT * FROM geom
WHERE type = 'Sporting Goods Store';

SELECT * FROM cw3.t2019_kar_land_use_a;

SELECT ST_AsText(geom) FROM cw3.t2019_kar_poi_table;
SELECT ST_AsText(geom) FROM cw3.t2019_kar_land_use_a;

SELECT DISTINCT poi.*
FROM cw3.t2019_kar_poi_table poi, cw3.t2019_kar_land_use_a lan
WHERE ST_DWithin(lan.geom, poi.geom, 0.0027) AND poi.type = 'Sporting Goods Store' AND lan.type='Park (City/County)';

-- 8. Znajdź punkty przecięcia torów kolejowych (RAILWAYS) z ciekami (WATER_LINES). Zapisz znalezioną geometrię do osobnej tabeli o nazwie ‘T2019_KAR_BRIDGES’.

SELECT *, ST_AsText(geom) FROM cw3.t2019_kar_railways;
SELECT *, ST_AsText(geom) FROM cw3.t2019_kar_water_lines;

SELECT DISTINCT
	cast(DENSE_RANK() OVER (ORDER BY  ST_Intersection(rai.geom, wat.geom)) AS INT) AS id,
	ST_AsText(ST_Intersection(rai.geom, wat.geom)) AS geom
FROM cw3.t2019_kar_railways rai, cw3.t2019_kar_water_lines wat; -- wyswietlanie, castujemy zeby zmienic BIGINT na INT

SELECT DISTINCT
	cast(DENSE_RANK() OVER (ORDER BY  ST_Intersection(rai.geom, wat.geom)) AS INT) AS id,
	ST_Intersection(rai.geom, wat.geom) AS geom
INTO TABLE cw3.T2019_KAR_BRIDGES
FROM cw3.t2019_kar_railways rai, cw3.t2019_kar_water_lines wat;

SELECT * FROM cw3.T2019_KAR_BRIDGES;


