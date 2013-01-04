require 'yaml'
require 'socket'
include Socket::Constants

class LightWaveRF

  @config_file = nil
  @config = nil

  def usage
    rooms = self.class.get_rooms self.get_config
    'usage: lightwaverf ' + rooms.keys.first + ' ' + rooms.values.first['device'].keys.first.to_s + ' on # where "' + rooms.keys.first + '" is a room in ' + self.get_config_file
  end

  def help
    help = self.usage + "\n"
    help += "your rooms, devices, and sequences, as defined in " + self.get_config_file + ":\n\n"
    help += YAML.dump self.get_config['room']
    room = self.get_config['room'].keys.last
    device = self.get_config['room'][room].last
    help += "\n\nso to turn on " + room + " " + device + " type \"lightwaverf " + room + " " + device + " on\"\n"
  end

  def set_config_file file
    @config_file = file
  end

  def get_config_file
    @config_file || File.expand_path('~') + '/lightwaverf-config.yml'
  end

  def get_config
    if ! @config
      if ! File.exists? self.get_config_file
        File.open( self.get_config_file, 'w' ) do | handle |
          handle.write YAML.dump( { 'host' => '192.168.0.14', 'room' => { 'our' => [ 'light', 'lights' ] }, 'sequence' => { 'lights' => [ [ 'our', 'light', 'on' ], [ 'our', 'lights', 'on' ] ] }} )
        end
      end
      @config = YAML.load_file self.get_config_file
    end
    @config
  end

  def self.get_rooms config = { 'room' => { }}
    rooms = { }
    r = 1
    config['room'].each do | name, devices |
      rooms[name] = { 'id' => 'R' + r.to_s, 'name' => name, 'device' => { }}
      d = 1
      devices.each do | device |
        # @todo possibly need to complicate this to get a device name back in here
        rooms[name]['device'][device] = 'D' + d.to_s
        d += 1
      end
      r += 1
    end
    rooms
  end

  # Translate the "state" we pass in to one the wifi link understands
  #
  # Example:
  #   >> LightWaveRF.new.state 'on' # 'F1'
  #   >> LightWaveRF.new.state 'off' # 'F0'
  #
  # Arguments:
  #   state: (String)
  def self.get_state state = 'on'
    case state
      when 'off'
        state = 'F0'
      when 'on'
        state = 'F1'
      when 1..100
        state = 'FdP' + ( state * 0.32 ).round.to_s
      else
        if state
          p 'did not recognise state, got ' + state
        end
    end
    state
  end

  # Get the command to send to the wifi link
  #
  # Example:
  #   >> LightWaveRF.new.command 'our', 'light', 'on'
  #
  # Arguments:
  #   room: (String)
  #   device: (String)
  #   state: (String)
  def command room, device, state
    # @todo get the device name in here...
   '666,!' + room['id'] + room['device'][device] + state + '|' + room['name'] + ' ' + room['id'] + '|via @pauly'
  end

  # Turn one of your devices on or off
  #
  # Example:
  #   >> LightWaveRF.new.send 'our', 'light', 'on'
  #
  # Arguments:
  #   room: (String)
  #   device: (String)
  #   state: (String)
  def send room = nil, device = nil, state = 'on', debug = false
    debug && ( puts 'config is ' + self.get_config.to_s )
    rooms = self.class.get_rooms self.get_config
    state = self.class.get_state state
    if rooms[room] && device && state && rooms[room]['device'][device]
      command = self.command rooms[room], device, state
      debug && ( p 'command is ' + command )
      self.raw command
    else
      STDERR.puts self.usage
    end
  end

  # A sequence of events
  # maybe I really mean a "mood" here?
  #
  # Example:
  #   >> LightWaveRF.new.sequence 'lights'
  #
  # Arguments:
  #   name: (String)
  #   debug: (Boolean)
  def sequence name, debug = false
    if self.get_config['sequence'][name]
      self.get_config['sequence'][name].each do | task |
        self.send task[0], task[1], task[2], debug
        sleep 1
      end
    end
  end

  def energy
    data = self.raw '666,@?'
    # /W=(?<usage>\d+),(?<max>\d+),(?<today>\d+),(?<yesterday>\d+)/.match data # ruby 1.9 only?
    match = /W=(\d+),(\d+),(\d+),(\d+)/.match data
    match and { 'usage' => match[1], 'max' => match[2], 'today' => match[3], 'yesterday' => match[4] }
  end

  def raw command
    response = nil
    begin
      listener = UDPSocket.new
      listener.bind '0.0.0.0', 9761
    rescue
      response = "can't bind to listen for a reply"
    end
    UDPSocket.new.send command, 0, self.get_config['host'], 9760
    if ! response
      response, addr = listener.recvfrom 200
      listener.close
    end
    response
  end

  # Use a google calendar as a timer?
  # Needs a google calendar, with its url in your config file, with events like "lounge light on" etc
  # Only the start time of the event is used right now.
  # 
  # Run this as a cron job every 5 mins, ie
  # */5 * * * * /usr/local/bin/lightwaverf timer 5 > /tmp/timer.out 2>&1
  # 
  # Example:
  #   >> LightWaveRF.new.timer
  #   >> LightWaveRF.new.state 10
  #
  # Sample calendar:
  #   https://www.google.com/calendar/feeds/aar79qh62fej54nprq6334s7ck%40group.calendar.google.com/public/basic
  #   https://www.google.com/calendar/embed?src=aar79qh62fej54nprq6334s7ck%40group.calendar.google.com&ctz=Europe/London 
  #
  # Arguments:
  #   interval: (Integer)
  #   debug: (Boolean)
  # 
  # @todo actually use the interval we said...
  def timer interval = 5, debug = false
    require 'net/http'
    require 'rexml/document'
    url = LightWaveRF.new.get_config['calendar'] + '?singleevents=true&start-min=' + Date.today.strftime( '%Y-%m-%d' ) + '&start-max=' + Date.today.next.strftime( '%Y-%m-%d' )
    debug && ( p url )
    parsed_url = URI.parse url
    http = Net::HTTP.new parsed_url.host, parsed_url.port
    http.use_ssl = true
    request = Net::HTTP::Get.new parsed_url.request_uri
    response = http.request request
    doc = REXML::Document.new response.body
    now = Time.now.strftime '%H:%M'
    five_mins = ( Time.now + 5 * 60 ).strftime '%H:%M'
    triggered = 0
    doc.elements.each 'feed/entry' do | e |
      command = /(\w+) (\w+) (\w+)/.match e.elements['title'].text # look for events with a title like 'lounge light on'
      if command
        room = command[1].to_s
        device = command[2].to_s
        status = command[3]
        timer = /When: ([\w ]+) (\d\d:\d\d) to ([\w ]+)?(\d\d:\d\d)/.match e.elements['summary'].text
        if timer
          from = timer[2].to_s # we only use the 'from' time right now
          to = timer[4] # we could use the 'to' time later, better for central heating events
        else
          STDERR.puts 'did not get When: in ' + e.elements['summary'].text
        end
        debug && ( p e.elements['title'] + ' - ' + now + ' < ' + from + ' < ' + five_mins + ' ?' )
        if from >= now && from < five_mins
          debug && ( p 'so going to turn the ' + room + ' ' + device + ' ' + status.to_s + ' now!' )
          self.send room, device, status.to_s
          triggered += 1
        end
      end
    end
    triggered.to_s + " events triggered"
  end
end

