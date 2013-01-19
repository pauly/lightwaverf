#!/usr/bin/ruby

# this one is not part of the lightwaverf gem, but used to summarise the data logged by lightwaverf.js node script

require 'json'
data = []
daily = {}
start_date = 0
File.open( "/home/pi/lightwaverf.log", "r" ).each_line do |line|
  line = JSON.parse( line )
  # data << [ 'new Date("' + line['timestamp'][0..15] + '")', line['message']['usage'], line['message']['annotation'] ? line['message']['annotation']['title'] : '', line['message']['annotation'] ? line['message']['annotation']['text'] : '' ]
  if line and line['timestamp']
    new_line = []
    # new_line << line['timestamp'][0..15] # original date
    d = line['timestamp'][2..3] + line['timestamp'][5..6] + line['timestamp'][8..9] # compact version of date
    dt = d + line['timestamp'][11..12] + line['timestamp'][14..15] # compact version of date
    dt = dt.to_i
    # p dt
    if start_date > 0
      dt = dt - start_date
    else
      start_date = dt
    end
    # p 'so now dt is ' + dt.to_s
    new_line << dt
    new_line << line['message']['usage'].to_i / 10
    if line['message']['annotation']
      new_line << line['message']['annotation']['title']
      new_line << line['message']['annotation']['text']
    end
    data << new_line
    # if ( ! daily[d] ) || ( line['message']['today'].to_i > daily[d] )
      daily[d] = line['message']['today']
    # end
  end
end
data = data.last( 1440 * 7 )
if data[0][0] != start_date
  data[0][0] += start_date
end
File.open( "/home/pi/lightwaverf-summary.json", "w" ) do |file|
  file.write data.last( 1440 * 7 )
end
File.open( "/home/pi/lightwaverf-daily.json", "w" ) do |file|
  file.write daily
end
