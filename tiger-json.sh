echo Converting Tiger Place Data
mkdir -p json
for full in ftp2.census.gov/geo/tiger/TIGER2014/PLACE/*zip
do
mkdir -p jail
echo $full
name=`basename "$full" .zip`
unzip $full -d jail
ogr2ogr -f geoJSON json/$name.json jail/$name.shp
ls -l json/$name.json
rm -rf jail
done

echo Unpacking Place Census
mkdir -p Place_2010Census
cd Place_2010Census
unzip ../Place_2010Census_DP1.zip
echo Converting Place Census
ogr2ogr -f geoJSON Place_2010Census_DP1.json Place_2010Census_DP1.shp

