require 'bundler/setup'
require 'rethinkdb'
require 'json'

include RethinkDB::Shortcuts

STATES = JSON.parse(File.read('FIPS.json'))

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

def geoify(geo)
  geo.map do |g|
    coords = g['geometry']['coordinates']

    puts "#{g['properties']['NAME']} polys #{coords.size}"
    primary_points = coords.shift
    unless sane?(primary_points)
      puts "WARNING: Dropping city."
      next
    end
    #puts "primary sample #{primary_points[0].inspect}"
    primary = r.polygon(*primary_points)

    coords.each do |co|
      pts = co
      #puts "hole sample #{pts[0].inspect}"
      hole = r.polygon(*pts)
      primary.polygon_sub(hole)
    end

    washed =  g['properties']
    washed['STATE'] = fips_state(washed["STATEFP"])
    {polygon: primary,
     properties: washed,
     slug: slugify(washed)}
  end.compact
end

puts "rethink connecting"
dbname = 'tiger'
conn = r.connect
r.db_create(dbname).run(conn) unless r.db_list().run(conn).include?(dbname)
conn.use(dbname)
r.table_create('cities').run(conn) rescue RethinkDB::RqlRuntimeError
r.table('cities').index_create('polygon', :geo => true).run(conn) rescue RethinkDB::RqlRuntimeError
r.table('cities').index_create('slug').run(conn) rescue RethinkDB::RqlRuntimeError
puts "rethink #{dbname} indexes #{r.table('cities').index_list.run(conn)}"
puts "rethink emptying #{dbname}"
r.table('cities').delete.run(conn)


total_tiger = 0
total_records = 0
total_saved = 0

ARGV.each do |fname|
  tiger = JSON.parse(File.read(fname))['features']
  records = geoify(tiger)
  puts "#{fname}: Inserting #{records.size} records"
  saved = 0
  records.each do |record|
    begin
      puts "saving #{record[:slug]} #{record[:properties]['NAME']} "
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

