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
    'usage: lightwaverf ' + rooms.values.first['name'] + ' ' + rooms.values.first['device'].keys.first.to_s + ' on # where "' + rooms.keys.first + '" is a room in ' + self.get_config_file
  end

  # Display help
  def help
    help = self.usage + "\n"
    help += "your rooms, devices, and sequences, as defined in " + self.get_config_file + ":\n\n"
    help += YAML.dump self.get_config['room']
    room = self.get_config['room'].last['name']
    device = self.get_config['room'].last['device'].last
    help += "\n\nso to turn on " + room + " " + device + " type \"lightwaverf " + room + " " + device + " on\"\n"
  end

  # Configure, build config file
  def configure
    config = { 'host' => self.get_config['host'], 'calendar' => self.get_config['calendar'] }
    puts 'What is the ip address of your wifi link? (' + self.get_config['host'] + ')'
    host = STDIN.gets.chomp
    if ! host.to_s.empty?
      config['host'] = host
    end
    device = 'x'
    while ! device.to_s.empty?
      puts 'Give me the name of a room and device, two words, space separated. For example "lounge light". Just hit enter to finish'
      if device = STDIN.gets.chomp
        puts 'got ' + device + ' now to split this up...'
      end
    end
    puts 'end of configure, config is now ' + config.to_s
    self.put_config config
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

  def put_config config = { 'host' => '192.168.1.64', 'room' => [ { 'name' => 'our', 'device' => [ 'light', 'lights' ] } ] }
    puts 'put_config got ' + config.to_s
    puts 'so writing ' + YAML.dump( config )
    File.open( self.get_config_file, 'w' ) do | handle |
      handle.write YAML.dump( config )
    end
  end

  # Get the config file, create it if it does not exist
  def get_config
    if ! @config
      if ! File.exists? self.get_config_file
        puts self.get_config_file + ' does not exist - copy lightwaverf-configy.yml from https://github.com/pauly/lightwaverf to your home directory or type lightwaverf configure'
        self.put_config
      end
      @config = YAML.load_file self.get_config_file
    end
    @config
  end

  # Update the LightWaveRF Gem config file from the LightWaveRF Host server
  #
  # Example:
  #   >> LightWaveRF.new.update_config 'name@example.com', '1234'
  #
  # Arguments:
  #   email: (String)
  #   pin: (String)
  #   debug: (Boolean)
  #
  # Credits:
  #   wonko - http://lightwaverfcommunity.org.uk/forums/topic/querying-configuration-information-from-the-lightwaverf-website/
  def update_config email = nil, pin = nil, debug = false
  
    # Login to LightWaveRF Host server
    require 'net/http'
    require 'uri'
    uri = URI.parse('https://lightwaverfhost.co.uk/manager/index.php')
    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
        require 'net/https'
        http.use_ssl = true
    end
    data = 'pin=' + pin + '&email=' + email
    headers = {'Content-Type'=> 'application/x-www-form-urlencoded'}
    resp, data = http.post(uri.request_uri, data, headers)
    
    if resp and resp.body
      # Extract JavaScript variables from the page
      #   var gDeviceNames = [""]
      #   var gDeviceStatus = [""]
      #   var gRoomNames = [""]
      #   var gRoomStatus = [""]
      # http://rubular.com/r/UH0H4b4afF
      variables = Hash.new
      resp.body.scan(/var (gDeviceNames|gDeviceStatus|gRoomNames|gRoomStatus)\s*=\s*([^;]*)/).each do |variable|
          variables[variable[0]] = variable[1].scan(/"([^"]*)\"/)
      end
      debug and (p '[Info - LightWaveRF Gem] Javascript variables ' + variables.to_s)
      
      rooms = Array.new
      # Rooms - gRoomNames is a collection of 8 values, or room names
      variables['gRoomNames'].each_with_index do |(roomName), roomIndex|
        # Room Status - gRoomStatus is a collection of 8 values indicating the status of the corresponding room in gRoomNames
        #   A: Active
        #   I: Inactive
        if variables['gRoomStatus'] and variables['gRoomStatus'][roomIndex] and variables['gRoomStatus'][roomIndex][0] == 'A'
          # Devices - gDeviceNames is a collection of 80 values, structured in blocks of ten values for each room:
          #   Devices 1 - 6, Mood 1 - 3, All Off
          roomDevices = Array.new
          deviceNamesIndexStart = roomIndex*10
          variables['gDeviceNames'][(deviceNamesIndexStart)..(deviceNamesIndexStart+5)].each_with_index do |(deviceName), deviceIndex|
            # Device Status - gDeviceStatus is a collection of 80 values which indicate the status/type of the corresponding device in gDeviceNames
            #   O: On/Off Switch
            #   D: Dimmer
            #   R: Radiator(s)
            #   P: Open/Close
            #   I: Inactive (i.e. not configured)
            #   m: Mood (inactive)
            #   M: Mood (active)
            #   o: All Off
            deviceStatusIndex = roomIndex*10+deviceIndex
            if variables['gDeviceStatus'] and variables['gDeviceStatus'][deviceStatusIndex] and variables['gDeviceStatus'][deviceStatusIndex][0] != 'I'
                roomDevices << deviceName
            end
          end
          # Create a hash of the active room and active devices and add to rooms array
          if roomName and roomDevices and roomDevices.any?
            rooms << {'name'=>roomName,'device'=>roomDevices}
          end
        end
      end
      
      # Update 'room' element in LightWaveRF Gem config file
      # config['room'] is an array of hashes containing the room name and device names
      # in the format { 'name' => 'Room Name', 'device' => ['Device 1', Device 2'] }
      if rooms and rooms.any?
        config = self.get_config
        config['room'] = rooms
        File.open( self.get_config_file, 'w' ) do | handle |
          handle.write YAML.dump( config )
        end
        debug and (p '[Info - LightWaveRF Gem] Updated config with ' + rooms.size.to_s + ' room(s): ' + rooms.to_s)
      else
        debug and (p '[Info - LightWaveRF Gem] Unable to update config: No active rooms or devices found')
      end
    else
      debug and (p '[Info - LightWaveRF Gem] Unable to update config: No response from Host server')
    end
    self.get_config
  end

  # Get a cleaned up version of the rooms and devices from the config file
  def self.get_rooms config = { 'room' => [ ]}, debug = false
    rooms = { }
    r = 1
    config['room'].each do | room |
      debug and ( puts room['name'] + ' = R' + r.to_s )
      rooms[room['name']] = { 'id' => 'R' + r.to_s, 'name' => room['name'], 'device' => { }}
      d = 1
      room['device'].each do | device |
        # @todo possibly need to complicate this to get a device name back in here
        debug and ( puts ' - ' + device + ' = D' + d.to_s )
        rooms[room['name']]['device'][device] = 'D' + d.to_s
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
    if /^\d+%?$/.match state.to_s
      state = state.to_i
    end
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
   '666,!' + room['id'] + room['device'][device] + state + '|' + room['name'] + ' ' + device + ' ' + state + '|via @pauly'
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
    rooms = self.class.get_rooms self.get_config, debug
    state = self.class.get_state state
    if rooms[room] and device and state and rooms[room]['device'][device]
      command = self.command rooms[room], device, state
      debug and ( p 'command is ' + command )
      data = self.raw command
      debug and ( p 'response is ' + data )
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
    begin
      http.use_ssl = true
    rescue
      debug && ( p 'cannot use ssl' )
    end
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

