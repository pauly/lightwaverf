#!/usr/bin/ruby

# this one is not part of the lightwaverf gem, but used to summarise the data logged by lightwaverf.js node script

require 'json'
data = []
File.open( "/home/pi/lightwaverf.log", "r" ).each_line do |line|
  line = JSON.parse( line )
  # data << [ line['timestamp'][11..15] + ' ' + line['timestamp'][5..9], line['message']['usage'] ]
  data << [ 'new Date("' + line['timestamp'][0..15] + '")', line['message']['usage'], line['message']['annotation'] ? line['message']['annotation']['title'] : '', line['message']['annotation'] ? line['message']['annotation']['text'] : '' ]
end
File.open( "/home/pi/lightwaverf-summary.json", "w" ) do |file|
  file.write data.last( 1440 ).to_json.gsub( /\\/, '' ).gsub( /"new/, 'new' ).gsub( /\)",/, '),' )
end
