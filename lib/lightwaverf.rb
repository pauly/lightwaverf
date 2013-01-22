require 'yaml'
require 'socket'
include Socket::Constants

class LightWaveRF

  @config_file = nil
  @log_file = nil
  @config = nil

  # Display usage info
  def usage
    rooms = self.class.get_rooms self.get_config
    'usage: lightwaverf ' + rooms.keys.first + ' ' + rooms.values.first['device'].keys.first.to_s + ' on # where "' + rooms.keys.first + '" is a room in ' + self.get_config_file
  end

  # Display help
  def help
    help = self.usage + "\n"
    help += "your rooms, devices, and sequences, as defined in " + self.get_config_file + ":\n\n"
    help += YAML.dump self.get_config['room']
    room = self.get_config['room'].keys.last
    device = self.get_config['room'][room].last
    help += "\n\nso to turn on " + room + " " + device + " type \"lightwaverf " + room + " " + device + " on\"\n"
  end

  # Config file setter
  def set_config_file file
    @config_file = file
  end

  # Config file getter
  def get_config_file
    @config_file || File.expand_path('~') + '/lightwaverf-config.yml'
  end

  # Log file getter
  def get_log_file
    @log_file || File.expand_path('~') + '/lightwaverf.log'
  end

  # Get the config file, create it if it does not exist
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

  # Get a cleaned up version of the rooms and devices from the config file
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
    debug and ( puts 'config is ' + self.get_config.to_s )
    rooms = self.class.get_rooms self.get_config
    state = self.class.get_state state
    if rooms[room] and device and state and rooms[room]['device'][device]
      command = self.command rooms[room], device, state
      debug and ( p 'command is ' + command )
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

  def energy title = nil, note = nil, debug = false
    debug and note and ( p 'energy: ' + note )
    data = self.raw '666,@?'
    debug and ( p data )
    # /W=(?<usage>\d+),(?<max>\d+),(?<today>\d+),(?<yesterday>\d+)/.match data # ruby 1.9 only?
    match = /W=(\d+),(\d+),(\d+),(\d+)/.match data
    debug and ( p match )
    if match
      data = { 'message' => { 'usage' => match[1].to_i, 'max' => match[2].to_i, 'today' => match[3].to_i }}
      data['timestamp'] = Time.now.to_s
      if note
        data['message']['annotation'] = { 'title' => title.to_s, 'text' => note.to_s }
      end
      debug and ( p data )
      require 'json'
      File.open( self.get_log_file, 'a' ) do |f|
        f.write( data.to_json + "\n" )
      end
      data['message']
    end
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
  def timer interval = 5, debug = false
    require 'net/http'
    require 'rexml/document'
    url = LightWaveRF.new.get_config['calendar'] + '?singleevents=true&start-min=' + Date.today.strftime( '%Y-%m-%d' ) + '&start-max=' + Date.today.next.strftime( '%Y-%m-%d' )
    debug and ( p url )
    parsed_url = URI.parse url
    http = Net::HTTP.new parsed_url.host, parsed_url.port
    http.use_ssl = true
    request = Net::HTTP::Get.new parsed_url.request_uri
    response = http.request request
    doc = REXML::Document.new response.body
    now = Time.now.strftime '%H:%M'
    interval_end_time = ( Time.now + interval.to_i * 60 ).strftime '%H:%M'
    triggered = []
    doc.elements.each 'feed/entry' do | e |
      command = /(\w+) (\w+)( (\w+))?/.match e.elements['title'].text # look for events with a title like 'lounge light on'
      if command
        room = command[1].to_s
        device = command[2].to_s
        status = command[4]
        timer = /When: ([\w ]+) (\d\d:\d\d) to ([\w ]+)?(\d\d:\d\d)/.match e.elements['summary'].text
        if timer
          event_time = timer[2].to_s
          event_end_time = timer[4]
        else
          STDERR.puts 'did not get When: in ' + e.elements['summary'].text
        end
        # @todo fix events that start and end in this period
        if status
          event_times = { event_time => status }
        else
          event_times = { event_time => 'on', event_end_time => 'off' }
        end
        event_times.each do | t, s |
          debug and ( p e.elements['title'].text + ' - ' + now + ' < ' + t + ' < ' + interval_end_time + ' ?' )
          if t >= now and t < interval_end_time
            debug and ( p 'so going to turn the ' + room + ' ' + device + ' ' + s.to_s + ' now!' )
            self.send room, device, s.to_s
            sleep 1
            triggered << [ room, device, s ]
          end
        end
      end
    end
    triggered.length.to_s + " events triggered"
    title = nil
    text = nil
    if triggered.length > 0
      debug and ( p triggered.length.to_s + ' events so annotating energy log too...' )
      title = 'timer'
      text = triggered.map { |e| e.join " " }.join ", "
    end
    self.energy title, text, debug
  end
end

