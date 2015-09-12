require 'bundler/setup'
require 'rethinkdb'
require 'json'

include RethinkDB::Shortcuts

STATES = JSON.parse(File.read('FIPS.json'))
CENSUS = {}

def flip(pts)
  pts.map {|c| [c[1], c[0]] }
end

def sane?(pts)
  pts.size > 1 && pts.all?{|p| p.size == 2 && p[0].is_a?(Float) && p[1].is_a?(Float)}
end

def fips_state(code)
  STATES["en"]["US"]["states"].select{|k,v| v[1] == code}
          .reduce([]){|m,e|m<<e[0];m}.first
end

def slugify(props)
  city = props["NAME"].encode("UTF-8", :invalid=>:replace, :replace=>"?").split(' ').join(' ').gsub(' ', '_')
  parts = [ "us", props["STATE"], city]
  parts.join('-').downcase
end

def census_scan
  puts "Loading Census GEOIP Populations"
  File.readlines('../../Place_2010Census/Place_2010Census.json').each do |line|
    match = line.match(/"GEOID10": "(\d+)".*"DP0010001": (\d+)/)
    CENSUS[match.captures[0]] = match.captures[1].to_i if match
  end
  puts "#{CENSUS.keys.size} Place Populations loaded"
end

def geoify(geo)
  geo.map do |g|
    geom = g['geometry']

    puts "#{g['properties']['NAME']} #{geom['type']} polys #{geom['coordinates'].size}"

    case geom['type']
    when "Polygon"
      outline = [r.geojson(geom)]
    when "MultiPolygon"
      outline = geom['coordinates'].map{|c| r.geojson({type:"Polygon", coordinates: c})}
    end

    washed =  g['properties']
    washed['STATE'] = fips_state(washed["STATEFP"])
    pop = CENSUS[washed["GEOID"]]
    washed['POPULATION'] = pop if pop

    {outline: outline,
     properties: washed,
     slug: slugify(washed)}
  end.compact
end

def db
  puts "rethinkdb connecting"
  dbname = 'tiger'
  table_name = 'cities'

  conn = r.connect
  r.db_create(dbname).run(conn) unless r.db_list().run(conn).include?(dbname)
  conn.use(dbname)
  r.table_drop(table_name).run(conn) if r.table_list().run(conn).include?(table_name)
  r.table_create(table_name).run(conn) rescue RethinkDB::RqlRuntimeError
  r.table(table_name).index_create('outline', {:multi => true, :geo => true}).run(conn) rescue RethinkDB::RqlRuntimeError
  r.table(table_name).index_create('slug').run(conn) rescue RethinkDB::RqlRuntimeError
  puts "rethink #{dbname} indexes #{r.table(table_name).index_list.run(conn)}"
  conn
end

conn = db
total_tiger = 0
total_records = 0
total_saved = 0

census_scan
ARGV.each do |fname|
  puts "Parsing #{fname}"
  tiger = JSON.parse(File.read(fname))['features']
  records = geoify(tiger)
  puts "#{fname}: Inserting #{records.size} records"
  saved = 0
  records.each do |record|
    begin
      puts "saving #{record[:slug]} #{record[:properties]['NAME']} POP: #{record[:properties]['POPULATION']}"
      r.table('cities').insert(record).run(conn)
      saved += 1
    rescue JSON::GeneratorError => e
      puts "Skipped: JSON err #{e}"
    rescue RethinkDB::RqlRuntimeError => e
      puts "Skipped: Rethink err #{e}"
    end
  end
  puts "#{fname} Tiger #{tiger.size}. Geo #{records.size}. Saved #{saved}"
  total_tiger += tiger.size
  total_records += records.size
  total_saved += saved
end

puts "DONE. Tiger #{total_tiger}. Geo #{total_records}. Saved #{total_saved}"

