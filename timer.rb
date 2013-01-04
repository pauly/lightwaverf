#!/usr/bin/ruby 

# Why not use a google calendar as a timer?
# Needs a google calendar, with its url in your config file, with events like "lounge light on" etc
# Only the start time of the event is used right now.
# 
# Run this as a cron job every 5 mins, ie
# */5 * * * * /home/pi/lightwaverf/timer.rb > /tmp/timer.out
# 
# now depracated by just "lightwaverf timer" in the gem itself

require 'lightwaverf'
require 'net/http'
require 'rexml/document'
url = LightWaveRF.new.get_config['calendar'] + '?singleevents=true&start-min=' + Date.today.strftime( '%Y-%m-%d' ) + '&start-max=' + Date.today.next.strftime( '%Y-%m-%d' )
p url
parsed_url = URI.parse url
http = Net::HTTP.new parsed_url.host, parsed_url.port
http.use_ssl = true
request = Net::HTTP::Get.new parsed_url.request_uri
response = http.request request
doc = REXML::Document.new response.body
now = Time.now.strftime '%H:%M'
five_mins = ( Time.now + 5 * 60 ).strftime '%H:%M'
doc.elements.each 'feed/entry' do | e |
  command = /(\w+) (\w+) (\w+)/.match e.elements['title'].text # look for events with a title like 'lounge light on'
  if command
    room = command[1].to_s
    device = command[2].to_s
    status = command[3]
    timer = /When: ([\w ]+) (\d\d:\d\d) to ([\w ]+)?(\d\d:\d\d)/.match e.elements['summary'].text
    if timer
      from = timer[2].to_s # we only use the from time right now
      to = timer[4] # we could use the to time later, better for heating events
    else
      p 'hmm did not get When: in ' + e.elements['summary'].text
    end
    if from >= now && from < five_mins
      p 'so going to turn the ' + room + ' ' + device + ' ' + status.to_s + ' now!'
      LightWaveRF.new.send room, device, status.to_s
    end
  end
end
