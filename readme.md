#Tiger2014

download, unpack, convert, and upload TIGER city data into RethinkDB.

From Sep 2015, TIGER City count is 29829 with about 2,900 cities dropped due to a polygon or name import error.
The properties.state is generated locally from a FIPS state catalog. The Slug is generated for a url-safe version of the name.

```json
{

    "id": "000d337f-5aa8-4f1c-b0a4-28e0fc78cf4b" ,
    "polygon": { ... } ,
    "properties": {
        "ALAND": 1507973 ,
        "AWATER": 0 ,
        "CLASSFP": "U1" ,
        "FUNCSTAT": "S" ,
        "GEOID": "1908020" ,
        "INTPTLAT": "+42.6367057" ,
        "INTPTLON": "-093.2489484" ,
        "LSAD": "57" ,
        "MTFCC": "G4210" ,
        "NAME": "Bradford" ,
        "NAMELSAD": "Bradford CDP" ,
        "PCICBSA": "N" ,
        "PCINECTA": "N" ,
        "PLACEFP": "08020" ,
        "PLACENS": "02585467" ,
        "STATE": "IA" ,
        "STATEFP": "19"
    } ,
    "slug": "us-ia-bradford"

}
```
