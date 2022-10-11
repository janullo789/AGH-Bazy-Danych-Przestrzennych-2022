-- a) Dodanie rozszerzenia

CREATE EXTENSION postgis;

-- b) Tworzenie tabeli

CREATE TABLE roads(id INT, name VARCHAR(50), geom GEOMETRY);
CREATE TABLE buildings(id INT, name VARCHAR(50), geom GEOMETRY, height INT);
CREATE TABLE pktinfo(id INT, name VARCHAR(50), geom GEOMETRY, nrWorks INT);

-- c) Uzupełnienie tabeli

-- POINT(x y)
-- LINESTRING(x1 y1, x2 y2, x3 y3)
-- POLYGON((x1 y1, x2 y2, x3 y3, x1 y1))

INSERT INTO roads VALUES(1, 'roadX', ST_GeomFromText('LINESTRING(0 4.5, 12 4.5)', 0))
INSERT INTO roads VALUES(2, 'roadY', ST_GeomFromText('LINESTRING(7.5 10.5, 7.5 0)', 0))

SELECT *, ST_AsText(roads.geom) AS WKT FROM roads;

INSERT INTO buildings VALUES(1, 'BuildingA', ST_GeomFromText('POLYGON((8 4, 10.5 4, 10.5 1.5, 8 1.5, 8 4))', 0), 20);
INSERT INTO buildings VALUES(2, 'BuildingB', ST_GeomFromText('POLYGON((4 7, 6 7, 6 5, 4 5, 4 7))', 0), 35);
INSERT INTO buildings VALUES(3, 'BuildingC', ST_GeomFromText('POLYGON((3 8, 5 8, 5 6, 3 6, 3 8))', 0), 55);
INSERT INTO buildings VALUES(4, 'BuildingD', ST_GeomFromText('POLYGON((9 9, 10 9, 10 8, 9 8, 9 9))', 0), 10);
INSERT INTO buildings VALUES(5, 'BuildingE', ST_GeomFromText('POLYGON((1 2, 2 2, 2 1, 1 1, 1 2))', 0), 5);
							 
SELECT *, ST_AsText(buildings.geom) AS WKT FROM buildings;

INSERT INTO pktinfo VALUES(1, 'G', ST_GeomFromText('POINT(1 3.5)', 0), 2);
INSERT INTO pktinfo VALUES(2, 'H', ST_GeomFromText('POINT(5.5 1.5)', 0), 1);
INSERT INTO pktinfo VALUES(3, 'I', ST_GeomFromText('POINT(9.5 6)', 0), 5);
INSERT INTO pktinfo VALUES(4, 'J', ST_GeomFromText('POINT(6.5 6)', 0), 2);
INSERT INTO pktinfo VALUES(5, 'K', ST_GeomFromText('POINT(6 9.5)', 0), 4);

SELECT *, ST_AsText(pktinfo.geom) AS WKT FROM pktinfo;

-- 1. Wyznacz całkowitą długość dróg w analizowanym mieście.

-- ST_Length(geom) -> DOUBLE

SELECT SUM(ST_Length(geom)) AS totalLength FROM roads;

-- 2. Wypisz geometrię (WKT), pole powierzchni oraz obwód poligonu reprezentującego BuildingA.

SELECT ST_AsText(buildings.geom) AS wkt, ST_Area(geom) AS area, ST_Perimeter(geom) AS perimeter FROM buildings
WHERE name = 'BuildingA';

-- 3. Wypisz nazwy i pola powierzchni wszystkich poligonów w warstwie budynki. Wyniki posortuj alfabetycznie. 

SELECT name, ST_Area(geom) AS area FROM buildings
ORDER BY name;

-- 4. Wypisz nazwy i obwody 2 budynków o największej powierzchni.

SELECT name, ST_Perimeter(geom) AS perimeter FROM buildings
ORDER BY ST_Area(geom) DESC LIMIT 2;

-- 5. Wyznacz najkrótszą odległość między budynkiem BuildingC a punktem G.

SELECT ST_Distance(bul.geom, pkt.geom) FROM buildings bul CROSS JOIN pktinfo pkt
WHERE bul.name = 'BuildingC' AND pkt.name = 'G';

-- 6. Wypisz pole powierzchni tej części budynku BuildingC, która znajduje się w odległości większej niż 0.5 od budynku BuildingB.

SELECT ST_Area(ST_Difference(
	(SELECT geom FROM buildings WHERE name = 'BuildingC'),
	(ST_Buffer((SELECT geom FROM buildings WHERE name = 'BuildingB'), 0.5))
));

-- 7. Wybierz te budynki, których centroid (ST_Centroid) znajduje się powyżej drogi RoadX.

SELECT name FROM buildings
WHERE (ST_Y((ST_Centroid(geom))) > 4.5);

-- 8. Oblicz pole powierzchni tych części budynku BuildingC i poligonu o współrzędnych (4 7, 6 7, 6 8, 4 8, 4 7), które nie są wspólne dla tych dwóch obiektów.

SELECT ST_Area(ST_SymDifference(
	(SELECT geom FROM buildings WHERE name = 'BuildingC'),
	ST_GeomFromText('POLYGON((4 7, 6 7, 6 8, 4 8, 4 7))')
))
