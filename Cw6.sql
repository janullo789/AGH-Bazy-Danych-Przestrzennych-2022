--------------------------------
-- 1.1 Przyciętcie rastra z wektorem (ST_Intersects - zwraca true jesli geometrie sie przecinaja)
CREATE TABLE skwarczenski.intersects AS
SELECT a.rast, b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality ilike 'porto';

-- 1.2 Dodanie serial primary key:
alter table skwarczenski.intersects
add column rid SERIAL PRIMARY KEY;

-- 1.3 Utworzenie indeksu przestrzennego:
CREATE INDEX idx_intersects_rast_gist ON skwarczenski.intersects
USING gist (ST_ConvexHull(rast)); --ST_ConvexHull zwaraca wypukłą geometrie

-- 1.4 Dodanie raster constraints:
-- schema::name table_name::name raster_column::name
SELECT AddRasterConstraints('skwarczenski'::name,
'intersects'::name,'rast'::name);

-- 2. Obcinanie rastra na podstawie wektora (ST_Clip)
CREATE TABLE skwarczenski.clip AS
SELECT ST_Clip(a.rast, b.geom, true), b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality like 'PORTO';

-- 3. Połączenie wielu kafelków w jeden raster (ST_Union)
CREATE TABLE skwarczenski.union AS
SELECT ST_Union(ST_Clip(a.rast, b.geom, true))
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast);

--------------------------------
-- 1. Przykład pokazuje użycie funkcji ST_AsRaster w celu rastrowania tabeli z parafiami o takiej
--		samej charakterystyce przestrzennej tj.: wielkość piksela, zakresy itp (ST_AsRaster - zmienia geom na raster)
CREATE TABLE skwarczenski.porto_parishes AS
WITH r AS (
	SELECT rast FROM rasters.dem
	LIMIT 1
)
SELECT ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

-- 2.  przykład łączy rekordy z poprzedniego przykładu przy użyciu funkcji ST_UNION w pojedynczy
--		raster (ST_Union)
DROP TABLE skwarczenski.porto_parishes; --> drop table porto_parishes first
CREATE TABLE skwarczenski.porto_parishes AS
WITH r AS (
	SELECT rast FROM rasters.dem
	LIMIT 1
)
SELECT st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767)) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

-- 3. Po uzyskaniu pojedynczego rastra można generować kafelki za pomocą funkcji ST_Tile (ST_Tile - zwaraca
--	zestaw rastrów powstawych w wyniku podziału)
DROP TABLE skwarczenski.porto_parishes; --> drop table porto_parishes first
CREATE TABLE skwarczenski.porto_parishes AS
WITH r AS (
	SELECT rast FROM rasters.dem
	LIMIT 1 )
SELECT st_tile(st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-
32767)),128,128,true,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

-------------------------------- Konwertowanie rastrów na wektory (wektoryzowanie)

-- 1. ST_Intersection
-- Funkcja St_Intersection jest podobna do ST_Clip. ST_Clip zwraca raster, a ST_Intersection zwraca
--	zestaw par wartości geometria-piksel, ponieważ ta funkcja przekształca raster w wektor przed
--	rzeczywistym „klipem”. Zazwyczaj ST_Intersection jest wolniejsze od ST_Clip więc zasadnym jest
--	przeprowadzenie operacji ST_Clip na rastrze przed wykonaniem funkcji ST_Intersection.
-- 	Zwraca wartości geomval

create table skwarczenski.intersection as
SELECT
a.rid,(ST_Intersection(b.geom,a.rast)).geom,(ST_Intersection(b.geom,a.rast)
).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast); --ilike nie patrzy na wielkosci liter

-- 2. ST_DumpAsPolygons
-- ST_DumpAsPolygons konwertuje rastry w wektory (poligony)
-- 	Zwraca wartości geomval
CREATE TABLE skwarczenski.dumppolygons AS
SELECT
a.rid,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).geom,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

-------------------- Analiza rastrów
-- 1. ST_Band (Funkcja ST_Band służy do wyodrębniania pasm z rastra, zwraca nowy raster)
CREATE TABLE skwarczenski.landsat_nir AS
SELECT rid, ST_Band(rast,4) AS rast
FROM rasters.landsat8;

-- 2. ST_Clip może być użyty do wycięcia rastra z innego rastra. Poniższy przykład wycina jedną parafię
--	z tabeli vectors.porto_parishes. Wynik będzie potrzebny do wykonania kolejnych przykładów.
CREATE TABLE skwarczenski.paranhos_dem AS
SELECT a.rid,ST_Clip(a.rast, b.geom,true) as rast
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);


-- 2. ST_Slope Poniższy przykład użycia funkcji ST_Slope wygeneruje nachylenie przy użyciu
--	poprzednio wygenerowanej tabeli (wzniesienie) (zwraca raster)

CREATE TABLE skwarczenski.paranhos_slope AS
SELECT a.rid,ST_Slope(a.rast,1,'32BF','PERCENTAGE') as rast
FROM skwarczenski.paranhos_dem AS a;

-- 3. Aby zreklasyfikować raster należy użyć funkcji ST_Reclass.
CREATE TABLE skwarczenski.paranhos_slope_reclass AS
SELECT a.rid,ST_Reclass(a.rast,1,']0-15]:1, (15-30]:2, (30-9999:3',
'32BF',0)
FROM skwarczenski.paranhos_slope AS a;

-- 4. Aby obliczyć statystyki rastra można użyć funkcji ST_SummaryStats. Poniższy przykład
--	wygeneruje statystyki dla kafelka.
-- ST_SummaryStats zwraca statystki zkladajace sie z liczby, sumy, sredniej, stddev, min, max

SELECT st_summarystats(a.rast) AS stats
FROM skwarczenski.paranhos_dem AS a;

-- 5. Przy użyciu UNION można wygenerować jedną statystykę wybranego rastra
SELECT st_summarystats(ST_Union(a.rast))
FROM skwarczenski.paranhos_dem AS a;

-- 6. ST_SummaryStats z lepszą kontrolą złożonego typu danych
WITH t AS (
	SELECT st_summarystats(ST_Union(a.rast)) AS stats
	FROM skwarczenski.paranhos_dem AS a
)
SELECT (stats).min,(stats).max,(stats).mean FROM t;

-- 7. ST_SummaryStats w połączeniu z GROUP BY
--	Aby wyświetlić statystykę dla każdego poligonu "parish" można użyć polecenia GROUP BY
WITH t AS (
	SELECT b.parish AS parish, st_summarystats(ST_Union(ST_Clip(a.rast,
	b.geom,true))) AS stats
	FROM rasters.dem AS a, vectors.porto_parishes AS b
	WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
	group by b.parish
)
SELECT parish,(stats).min,(stats).max,(stats).mean FROM t;

-- 9. ST_Value
--	Funkcja ST_Value pozwala wyodrębnić wartość piksela z punktu lub zestawu punktów.
--		Poniższy przykład wyodrębnia punkty znajdujące się w tabeli vectors.places.
--		Ponieważ geometria punktów jest wielopunktowa, a funkcja ST_Value wymaga geometrii
--		jednopunktowej, należy przekonwertować geometrię wielopunktową na geometrię
--		jednopunktową za pomocą funkcji (ST_Dump(b.geom)).geom.

SELECT b.name,st_value(a.rast,(ST_Dump(b.geom)).geom)
FROM
rasters.dem a, vectors.places AS b
WHERE ST_Intersects(a.rast,b.geom)
ORDER BY b.name;

---------------Topographic Position Index (TPI)
-- TPI porównuje wysokość każdej komórki w DEM ze średnią wysokością określonego sąsiedztwa
--	wokół tej komórki. Wartości dodatnie reprezentują lokalizacje, które są wyższe niż średnia ich
--	otoczenia, zgodnie z definicją sąsiedztwa (grzbietów). Wartości ujemne reprezentują lokalizacje,
--	które są niższe niż ich otoczenie (doliny). Wartości TPI bliskie zeru to albo płaskie obszary (gdzie
--	nachylenie jest bliskie zeru), albo obszary o stałym nachyleniu

-- 1. ST_TPI
--	Funkcja ST_Value pozwala na utworzenie mapy TPI z DEM wysokości. Obecna wersja PostGIS może
--	obliczyć TPI jednego piksela za pomocą sąsiedztwa wokół tylko jednej komórki. Poniższy przykład
--	pokazuje jak obliczyć TPI przy użyciu tabeli rasters.dem jako danych wejściowych. Tabela nazywa się
--	TPI30 ponieważ ma rozdzielczość 30 metrów i TPI używa tylko jednej komórki sąsiedztwa do
--	obliczeń.
create table skwarczenski.tpi30 as
select ST_TPI(a.rast,1) as rast
from rasters.dem a; -- 43.3 sekundy

-- Poniższa kwerenda utworzy indeks przestrzenny:
CREATE INDEX idx_tpi30_rast_gist ON skwarczenski.tpi30
USING gist (ST_ConvexHull(rast));

-- Dodanie constraintów:
SELECT AddRasterConstraints('skwarczenski'::name,
'tpi30'::name,'rast'::name);

-- Przetwarzanie poprzedniego zapytania może potrwać dłużej niż minutę, a niektóre zapytania mogą
--	potrwać zbyt długo. W celu skrócenia czasu przetwarzania czasami można ograniczyć obszar
--	zainteresowania i obliczyć mniejszy region. Dostosuj zapytanie z przykładu 10, aby przetwarzać tylko
--	gminę Porto.
create table skwarczenski.tpi30_porto as
SELECT ST_TPI(a.rast,1) as rast
FROM rasters.dem AS a, vectors.porto_parishes AS b 
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality ilike 'porto'; --1.7 sekundy

CREATE INDEX idx_tpi30_porto_rast_gist ON skwarczenski.tpi30_porto
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('skwarczenski'::name, 
'tpi30_porto'::name,'rast'::name);

------------ Algebra map
-- Istnieją dwa sposoby korzystania z algebry map w PostGIS. Jednym z nich jest użycie wyrażenia,
-- a drugim użycie funkcji zwrotnej. Poniższe przykłady pokazują jak stosując obie techniki
-- utworzyć wartości NDVI na podstawie obrazu Landsat8.
-- NDVI=(NIR-Red)/(NIR+Red)

-- 1. Wyrażenie Algebry Map
CREATE TABLE skwarczenski.porto_ndvi AS
WITH r AS (
	SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
	FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT
	r.rid,ST_MapAlgebra(
		r.rast, 1,
		r.rast, 4,
			'([rast2.val] - [rast1.val]) / ([rast2.val] +
			[rast1.val])::float','32BF'
	) AS rast
FROM r;

-- Poniższe zapytanie utworzy indeks przestrzenny na wcześniej stworzonej tabeli:
CREATE INDEX idx_porto_ndvi_rast_gist ON skwarczenski.porto_ndvi
USING gist (ST_ConvexHull(rast));

-- Dodanie constraintów:
SELECT AddRasterConstraints('skwarczenski'::name,
'porto_ndvi'::name,'rast'::name);

-- 2. Funkcja zwrotna
--	W pierwszym kroku należy utworzyć funkcję, które będzie wywołana później:
create or replace function skwarczenski.ndvi(
	value double precision [] [] [],
	pos integer [][],
	VARIADIC userargs text []
)
RETURNS double precision AS
$$
BEGIN
	--RAISE NOTICE 'Pixel Value: %', value [1][1][1];-->For debug purposes
	RETURN (value [2][1][1] - value [1][1][1])/(value [2][1][1]+value
[1][1][1]); --> NDVI calculation!
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE COST 1000;

-- W kwerendzie algebry map należy można wywołać zdefiniowaną wcześniej funkcję:
CREATE TABLE skwarczenski.porto_ndvi2 AS
WITH r AS (
	SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
	FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
	WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT
	r.rid,ST_MapAlgebra(
		r.rast, ARRAY[1,4],
		'skwarczenski.ndvi(double precision[],
		integer[],text[])'::regprocedure, --> This is the function!
'32BF'::text
	) AS rast
FROM r;

-- Dodanie indeksu przestrzennego:
CREATE INDEX idx_porto_ndvi2_rast_gist ON skwarczenski.porto_ndvi2
USING gist (ST_ConvexHull(rast));

-- Dodanie constraintów:
SELECT AddRasterConstraints('skwarczenski'::name,
'porto_ndvi2'::name,'rast'::name);

------------ Eksport danych
-- 1. ST_AsTiff zapisuje raster w tiff
SELECT ST_AsTiff(ST_Union(rast))
FROM skwarczenski.porto_ndvi;

-- 2. ST_AsGDALRaster
--	Podobnie do funkcji ST_AsTiff, ST_AsGDALRaster nie zapisuje danych wyjściowych bezpośrednio
--	na dysku, natomiast dane wyjściowe są reprezentacją binarną dowolnego formatu GDAL.
SELECT ST_AsGDALRaster(ST_Union(rast), 'GTiff', ARRAY['COMPRESS=DEFLATE',
'PREDICTOR=2', 'PZLEVEL=9'])
FROM skwarczenski.porto_ndvi;

-- Funkcje ST_AsGDALRaster pozwalają nam zapisać raster w dowolnym formacie obsługiwanym przez
--gdal. Aby wyświetlić listę formatów obsługiwanych przez bibliotekę uruchom:
SELECT ST_GDALDrivers();

-- 3. - Zapisywanie danych na dysku za pomocą dużego obiektu (large object, lo)
CREATE TABLE tmp_out AS
SELECT lo_from_bytea(0,
ST_AsGDALRaster(ST_Union(rast), 'GTiff', ARRAY['COMPRESS=DEFLATE',
'PREDICTOR=2', 'PZLEVEL=9'])
) AS loid
FROM skwarczenski.porto_ndvi;
----------------------------------------------
SELECT lo_export(loid, 'D:\Bazydanych\myraster.tiff') --> Save the file in a place where the user postgres have access. In windows a flash drive usualy works fine.
FROM tmp_out;
----------------------------------------------
SELECT lo_unlink(loid)
FROM tmp_out; --> Delete the large object.

