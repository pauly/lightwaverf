#!/usr/bin/ruby

# this one is not part of the lightwaverf gem, but used to summarise the data logged by lightwaverf.js node script

require 'json'
data = []
File.open( "/home/pi/lightwaverf.log", "r" ).each_line do |line|
  line = JSON.parse( line )
  # data << [ 'new Date("' + line['timestamp'][0..15] + '")', line['message']['usage'], line['message']['annotation'] ? line['message']['annotation']['title'] : '', line['message']['annotation'] ? line['message']['annotation']['text'] : '' ]
  new_line = []
  # new_line << line['timestamp'][0..15] # original date
  new_line << line['timestamp'][2..3] + line['timestamp'][5..6] + line['timestamp'][8..9] + line['timestamp'][11..12] + line['timestamp'][14..15] # compact version of date
  new_line << line['message']['usage'] / 10
  if line['message']['annotation']
    new_line << line['message']['title']
    new_line << line['message']['text']
  end
  data << new_line
end
File.open( "/home/pi/lightwaverf-summary.json", "w" ) do |file|
  file.write data.last( 1440 * 7 ).to_json.gsub( /"/, '' )
end
