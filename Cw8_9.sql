-- 2. Załaduj te dane do tabeli o nazwie uk_250k.

-- CMD
-- raster2pgsql -s 27700 -I -N -32767 -C -M
-- "C:\Users\Dell\Documents\Studia\Semestr 5\Bazy danych przestrzennych\Cw8-9_2022_11_28\ras250_gb\data\*.tif" -F -t 100x100 rasters.uk_250k 
-- | .\psql -d gisbdCw89 -h localhost -U postgres -p 5432

SELECT * FROM rasters.uk_250k;

-- utworzenie indeksu przestrzennego
CREATE INDEX idx_uk_250k ON rasters.uk_250k
USING gist (ST_ConvexHull(rast));

-- dodanie raster constraints
-- schema::name table_name::name raster_column::name
SELECT AddRasterConstraints('raster'::name,'uk_250k'::name,'rast'::name);

-- 5. Załaduj do bazy danych tabelę reprezentującą granice parków narodowych.
-- shp2pgsql -s 27700 "C:\Users\Dell\Documents\Studia\Semestr 5\Bazy danych przestrzennych\Cw8-9_2022_11_28\parks\parks.shp" rasters.parks | .\psql -d gisbdCw89 -h localhost -U postgres -p 5432
SELECT * FROM rasters.parks;

-- 6. Utwórz nową tabelę o nazwie uk_lake_district, do której zaimportujesz mapy rastrowe z punktu 1., które zostaną przycięte do granic parku narodowego Lake District.
CREATE TABLE raster.uk_lake_district AS
SELECT r.rid, ST_Clip(r.rast, p.geom, true) AS rast, p.id
FROM rasters.uk_250k AS r, rasters.parks AS p
WHERE ST_Intersects(r.rast, p.geom) AND p.id = 1;

-- 7. Wyeksportuj wyniki do pliku GeoTIFF.
CREATE TABLE tmp_out AS
SELECT lo_from_bytea(0,
       ST_AsGDALRaster(ST_Union(rast), 'GTiff',  ARRAY['COMPRESS=DEFLATE', 'PREDICTOR=2', 'PZLEVEL=9'])
        ) AS loid
FROM rasters.uk_lake_district;

SELECT lo_export(loid, "C:\Users\Dell\Documents\Studia\Semestr 5\Bazy danych przestrzennych\Cw8-9_2022_11_28\ras250_gb\data\uk_lake_district.tiff");
FROM tmp_out;

SELECT lo_unlink(loid)
FROM tmp_out; 

DROP TABLE tmp_out;

-- 9.  Załaduj dane z Sentinela-2 do bazy danych.
--raster2pgsql -s 27700 -I -N -32767 -C -M "C:\Users\Dell\Documents\Studia\Semestr 5\Bazy danych przestrzennych\Cw8-9_2022_11_28\dane_landsat2\landsat_lewy\GRANULE\L1C_T30UVF_A038973_20221208T113452\IMG_DATA\B03.jp2" -F -t 100x100 rasters.landsat_lewy | .\psql -d gisbdCw89 -h localhost -U postgres -p 5432
--raster2pgsql -s 27700 -I -N -32767 -C -M "C:\Users\Dell\Documents\Studia\Semestr 5\Bazy danych przestrzennych\Cw8-9_2022_11_28\dane_landsat2\landsat_prawy\GRANULE\L2A_T30UWF_A029707_20221113T113318\IMG_DATA\R10m\B08.jp2" -F -t 100x100 rasters.landsat_prawy | .\psql -d gisbdCw89 -h localhost -U postgres -p 5432
SELECT * FROM rasters.landsat_lewy
SELECT * FROM rasters.landsat_prawy

-- 10. Policz indeks NDWI oraz przytnij wyniki do granic Lake District.
WITH r1 AS (
(SELECT ST_Union(ST_Clip(a.rast, ST_Transform(b.geom, 32630), true)) AS rast
FROM rasters.landsat_lewy AS a, rasters.parks AS b
WHERE ST_Intersects(a.rast, ST_Transform(b.geom, 32630)) AND b.id = 1))
,
r2 AS (
(SELECT ST_Union(ST_Clip(a.rast, ST_Transform(b.geom, 32630), true)) AS rast
FROM rasters.landsat_prawy AS a, rasters.parks AS b
WHERE ST_Intersects(a.rast, ST_Transform(b.geom, 32630)) AND b.id = 1))

SELECT ST_MapAlgebra(r1.rast, r2.rast, '([rast1.val]-[rast2.val])/([rast1.val]+[rast2.val])::float', '32BF') AS rast
INTO lake_district_ndwi FROM r1, r2;

-- 11.
CREATE TABLE tmp_out AS
SELECT lo_from_bytea(0,
       ST_AsGDALRaster(ST_Union(rast), 'GTiff',  ARRAY['COMPRESS=DEFLATE', 'PREDICTOR=2', 'PZLEVEL=9'])
        ) AS loid
FROM rasters.uk_lake_district_ndwi;

SELECT lo_export(loid, "C:\Users\Dell\Documents\Studia\Semestr 5\Bazy danych przestrzennych\Cw8-9_2022_11_28\data\uk_lake_district_ndwi.tiff")
FROM tmp_out;

SELECT lo_unlink(loid)
FROM tmp_out; 

DROP TABLE tmp_out;
