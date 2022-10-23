-- 4. Wyznacz liczbę budynków (tabela: popp, atrybut: f_codedesc, reprezentowane, jako punkty) położonych w odległości mniejszej niż 
--	1000 m od głównych rzek. Budynki spełniające to kryterium zapisz do osobnej tabeli tableB.

SELECT *, ST_AsText(geom) FROM popp;
SELECT *, ST_AsText(geom) FROM majrivers;

SELECT DISTINCT po.* INTO tableB FROM popp po, majrivers ma
WHERE(ST_CONTAINS(ST_BUFFER(ma.geom, 1000), po.geom)) AND (po.f_codedesc = 'Building'); -- dodanie do tabeli

SELECT * FROM tableB;

SELECT DISTINCT po.* FROM popp po, majrivers ma
WHERE(ST_CONTAINS(ST_BUFFER(ma.geom, 1000), po.geom)) AND (po.f_codedesc = 'Building'); -- wyświetlnie

-- 5. Utwórz tabelę o nazwie airportsNew. Z tabeli airports do zaimportuj nazwy lotnisk, ich geometrię, a także atrybut elev, reprezentujący wysokość
--	n.p.m.

SELECT * FROM airports;

SELECT name, geom, elev INTO airportsNew FROM airports;

SELECT *, ST_AsText(geom) FROM airportsNew;

-- 5a. Znajdź lotnisko, które położone jest najbardziej na zachód i najbardziej na wschód.

-- na zachód
SELECT *, ST_AsText(geom) FROM airportsNew
ORDER BY ST_X(geom) LIMIT 1;

-- na wschód
SELECT *, ST_AsText(geom) FROM airportsNew
ORDER BY ST_X(geom) DESC LIMIT 1;

-- 5b. Do tabeli airportsNew dodaj nowy obiekt - lotnisko, które położone jest w punkcie środkowym drogi pomiędzy lotniskami znalezionymi w punkcie a.
--	Lotnisko nazwij airportB. Wysokość n.p.m. przyjmij dowolną.

INSERT INTO airportsNew (name, geom, elev) VALUES (
'airportB',
ST_CENTROID(ST_COLLECT(
	(SELECT geom FROM airportsNew ORDER BY ST_X(geom) LIMIT 1), 
	(SELECT geom FROM airportsNew ORDER BY ST_X(geom) DESC LIMIT 1))),
234
)

-- 6. Wyznacz pole powierzchni obszaru, który oddalony jest mniej niż 1000 jednostek od najkrótszej linii łączącej jezioro o nazwie ‘Iliamna Lake’ i
--	lotnisko o nazwie „AMBLER”

SELECT * FROM airports;
SELECT *, ST_AsText(geom) FROM lakes;

SELECT ST_AREA(ST_BUFFER(ST_MAKELINE(
							(SELECT ST_CENTROID(geom) FROM lakes WHERE names = 'Iliamna Lake'),
							(SELECT geom FROM airports WHERE name = 'AMBLER')
), 1000))

-- 7.  Napisz zapytanie, które zwróci sumaryczne pole powierzchni poligonów reprezentujących poszczególne typy drzew znajdujących się na obszarze
--	tundry i bagien (swamps).

SELECT *, ST_AsText(geom) FROM swamp;
SELECT *, ST_AsText(geom) FROM tundra;
SELECT *, ST_AsText(geom) FROM trees;

SELECT trees.vegdesc, SUM(ST_Area(trees.geom)) AS area
	FROM trees, tundra, swamp
	WHERE ST_Within(trees.geom, tundra.geom)  OR ST_Within(trees.geom, swamp.geom)
	GROUP BY trees.vegdesc;



