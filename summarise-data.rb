#!/usr/bin/ruby

# this one is not part of the lightwaverf gem, but used to summarise the data logged by lightwaverf.js node script

require 'json'
data = []
File.open( "/home/pi/lightwaverf.log", "r" ).each_line do |line|
  line = JSON.parse( line )
  data << [ line['timestamp'][11..15] + ' ' + line['timestamp'][5..9], line['message']['usage'] ]
end
File.open( "/home/pi/lightwaverf-summary.json", "w" ) do |file|
  file.write data.last( 1440 ).unshift( [ 'timestamp', 'usage' ] ).to_json
end
