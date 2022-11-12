-- utworzenie tabeli i wpisane danych

CREATE TABLE cw5.obiekty(id INT, geom GEOMETRY);

INSERT INTO cw5.obiekty
VALUES(
	1, 
	ST_GeomFromText('CIRCULARSTRING(0 1, 0.5 1, 1 1, 2 0, 3 1, 4 2, 5 1, 5.5 1, 6 1)')
);

INSERT INTO cw5.obiekty
VALUES(
	2, 
	ST_GeomFromText('CURVEPOLYGON(
					CIRCULARSTRING(10 6, 12 6, 14 6, 16 4, 14 2, 12 0, 10 2, 10 4, 10 6), 
				   	CIRCULARSTRING(11 2, 12 3, 13 2, 12 1, 11 2))')
);

INSERT INTO cw5.obiekty
VALUES(
	3, 
	ST_GeomFromText('COMPOUNDCURVE((7 15, 10 17), (10 17, 12 13), (12 13, 7 15))')
);

INSERT INTO cw5.obiekty
VALUES(
	4, 
	ST_GeomFromText('COMPOUNDCURVE((20 20, 25 25), (25 25, 27 24), (27 24, 25 22), (25 22, 26 21), (26 21, 22 19), (22 19, 20.5 19.5))')
);

INSERT INTO cw5.obiekty
VALUES(
	5,
	ST_GeomFromText('MULTIPOINT((30 30 59), (38 32 234))')
);

INSERT INTO cw5.obiekty
VALUES(
	6,
	ST_GeomFromText('GEOMETRYCOLLECTION(LINESTRING(1 1, 3 2), POINT(4 2))')
);

SELECT *, ST_AsText(geom) FROM cw5.obiekty;

-- 1. . Wyznacz pole powierzchni bufora o wielkości 5 jednostek, który został utworzony wokół najkrótszej
--		linii łączącej obiekt 3 i 4.

SELECT ST_AREA(
		ST_BUFFER(
		ST_SHORTESTLINE(
			(SELECT geom FROM cw5.obiekty WHERE id = 3),
			(SELECT geom FROM cw5.obiekty WHERE id = 4)
), 5));

-- 2. Zamień obiekt4 na poligon. Jaki warunek musi być spełniony, aby można było wykonać to zadanie?
-- Zapewnij te warunki.

UPDATE cw5.obiekty
SET geom = ST_MAKEPOLYGON(ST_LineMerge(ST_Collect(
										(ST_CurveToLine((SELECT geom FROM cw5.obiekty WHERE id = 4))),
										(ST_CurveToLine(ST_GeomFromText('COMPOUNDCURVE((20.5 19.5, 20 20))')))
)))
WHERE id = 4; --ST_LineMarge merguje multiLineString na lineString dzieki czemu mozna zrobic polygon
		
-- 3. W tabeli obiekty, jako obiekt7 zapisz obiekt złożony z obiektu 3 i obiektu 4.

INSERT INTO cw5.obiekty
VALUES(
	7,
	ST_Collect(
		(SELECT geom FROM cw5.obiekty WHERE id = 3),
		(SELECT geom FROM cw5.obiekty WHERE id = 4)
	)
);

-- 4.  Wyznacz pole powierzchni wszystkich buforów o wielkości 5 jednostek, które zostały utworzone
--		wokół obiektów nie zawierających łuków.

SELECT SUM(ST_Area(ST_Buffer(geom, 5)))
FROM cw5.obiekty
WHERE NOT ST_HasArc(geom);

