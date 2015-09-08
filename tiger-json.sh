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
