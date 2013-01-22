#!/usr/bin/ruby

# this one is not part of the lightwaverf gem, but used to summarise the data logged by lightwaverf.js node script

require 'json'
require 'time'
data = []
daily = {}
start_date = 0
d = nil
File.open( '/home/pi/lightwaverf.log', 'r' ).each_line do |line|
  line = JSON.parse( line )
  if line and line['timestamp']
    new_line = []
    d = line['timestamp'][2..3] + line['timestamp'][5..6] + line['timestamp'][8..9] # compact version of date
    # p 'ts = Time.new( ' + line['timestamp'] + ' )'
    ts = Time.parse( line['timestamp'] ).strftime '%s'
    ts = ts.to_i
    if start_date > 0
      # p 'ts = ' + ts.to_s + ' - ' + start_date.to_s
      ts = ts - start_date
    else
      start_date = ts
    end
    # p 'so now ts is ' + ts.to_s
    new_line << ts
    new_line << line['message']['usage'].to_i / 10
    if line['message']['annotation'] and line['message']['annotation']['title'] and line['message']['annotation']['text']
      new_line << line['message']['annotation']['title']
      new_line << line['message']['annotation']['text']
    end
    data << new_line
    daily[d] = line['message']['today']
  end
end
data = data.last( 60 * 24 * 7 )
if data[0][0] != start_date
  data[0][0] += start_date
end
File.open( '/home/pi/lightwaverf-summary.json', 'w' ) do |file|
  file.write data
end
File.open( '/home/pi/lightwaverf-daily.json', 'w' ) do |file|
  file.write daily
end
File.open( '/home/pi/lightwaverf-daily.' + d + '.json', 'w' ) do |file|
  file.write daily
end
