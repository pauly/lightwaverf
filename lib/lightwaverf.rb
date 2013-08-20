# TODO:
# All day events without times - need to fix regex
# Make regex better
# Get rid of references in yaml cache file - use dup more? Or does it not matter?
# Cope with events that start and end in the same run?
# Add info about states to timer log
# Consider adding a 'random' time shift modifier to make holiday security lights more 'realistic'


require 'yaml'
require 'socket'
include Socket::Constants

class LightWaveRF

  @config_file = nil
  @log_file = nil
  @log_timer_file = nil
  @config = nil
  @timers = nil

  # Display usage info
  def usage
    rooms = self.class.get_rooms self.get_config
    'usage: lightwaverf ' + rooms.values.first['name'] + ' ' + rooms.values.first['device'].keys.first.to_s + ' on # where "' + rooms.keys.first + '" is a room in ' + self.get_config_file
  end

  # Display help
  def help
    config = self.get_config
    help = self.usage + "\n"
    help += "your rooms, devices, and sequences, as defined in " + self.get_config_file + ":\n\n"
    help += YAML.dump config
    help += "interpreted room configuration:\n\n"
    help += YAML.dump self.class.get_rooms config
    room = self.get_config['room'].last['name']
    device = self.get_config['room'].last['device'].last
    help += "\n\nso to turn on " + room + " " + device + " type \"lightwaverf " + room + " " + device + " on\"\n"
  end

  # Configure, build config file. Interactive command line stuff
  #
  # Arguments:
  #   debug: (Boolean
  def configure debug = false
    config = self.get_config
    puts 'What is the ip address of your wifi link? (' + self.get_config['host'] + '). Enter a blank line to broadcast UDP commands.'
    host = STDIN.gets.chomp
    if ! host.to_s.empty?
      config['host'] = host
    end
    puts 'What is the address of your google calendar? (' + self.get_config['calendar'] + '). Optional!'
    calendar = STDIN.gets.chomp
    if ! calendar.to_s.empty?
      config['calendar'] = calendar
    end
    device = 'x'
    while ! device.to_s.empty?
      puts 'Enter the name of a room and its devices, space separated. For example "lounge light socket tv". Enter a blank line to finish.'
      if device = STDIN.gets.chomp
        parts = device.split ' '
        if !parts[0].to_s.empty? and !parts[1].to_s.empty?
          new_room = parts.shift
          if ! config['room']
            config['room'] = [ ]
          end
          found = false
          config['room'].each do | room |
            if room['name'] == new_room
              room['device'] = parts
              found = true
            end
            debug and ( p 'so now room is ' + room.to_s )
          end
          if ! found
            config['room'].push 'name' => new_room, 'device' => parts, 'mood' => nil
          end
          debug and ( p 'added ' + parts.to_s + ' to ' + new_room )
        end
      end
    end
    debug and ( p 'end of configure, config is now ' + config.to_s )
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

  # Timer log file getter
  def get_timer_log_file
    @timer_log_file || File.expand_path('~') + '/lightwaverf-timer.log'
  end
  
  # Timer logger
  def log_timer_event type, room = nil, device = nil, state = nil, result = false
    # create log message
    message = nil
    case type
    when 'update'
      message = '### Updated timer cache'
    when 'run'
      message = '*** Ran timers'
    when 'sequence'
      message = 'Ran sequence: ' + state
    when 'mood'
      message = 'Set mood: ' + mood + ' in room ' + room
    when 'device'
      message = 'Set device: ' + device + ' in room ' + room + ' to state ' + state
    end
    unless message.nil?
      File.open( self.get_timer_log_file, 'a' ) do |f|      
        f.write("\n" + Time.now.to_s + ' - ' + message + ' - ' + ( result ? 'SUCCESS!' : 'FAILED!' ))
      end
    end
  end

  # Timer cache file getter
  def get_timer_cache_file
    @log_file || File.expand_path('~') + '/lightwaverf-timer-cache.yml'
  end
  
  # Get timer cache file, create it if needed
  def get_timer_cache
    if ! @timers
      if ! File.exists? self.get_timer_cache_file
        self.put_timer_cache
      end
      @timers = YAML.load_file self.get_timer_cache_file
    end
    @timers
  end
  
  # Store the timer cache
  def put_timer_cache timers = { 'events' => [] }
    #puts 'put_timer_cache got ' + timers.to_s
    puts 'so writing ' + YAML.dump( timers)
    File.open( self.get_timer_cache_file, 'w' ) do | handle |
      handle.write YAML.dump( timers )
    end
  end  

  def put_config config = { 'room' => [ { 'name' => 'our', 'device' => [ 'light', 'lights' ] } ] }
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
      # Create skeleton config
      rooms[room['name']] = {
          'id' => 'R' + r.to_s,
          'name' => room['name'],
          'device' => { },
          'mood' => { },
          'learnmood' => { },
          'exclude_room' => (room.has_key?('exclude') and room['exclude'].has_key?('room')) ? room['exclude']['room'] : false,
          'exclude_device' => { }
      }
      # Add device exclusions
      if room.has_key?('exclude') and room['exclude'].has_key?('device')
        room['exclude']['device'].each do | device |
          rooms[room['name']]['exclude_device'][device] = true
        end
      end
      # Add any devices
      d = 1
      unless room['device'].nil?
        room['device'].each do | device |
          # @todo possibly need to complicate this to get a device name back in here
          debug and ( puts ' - ' + device + ' = D' + d.to_s )
          rooms[room['name']]['device'][device] = 'D' + d.to_s
          #Add any device aliases as copies with the same device code
          if room.has_key?('aliases') and room['aliases'].has_key?('device') and room['aliases']['device'].has_key?(device)
            room['aliases']['device'][device].each do | aliasname |
              rooms[room['name']]['device'][aliasname] = 'D' + d.to_s
              # Always exlcude alias devices
              rooms[room['name']]['exclude_device'][aliasname] = true
            end
          end
          d += 1
        end
      end
      # Add any moods
      m = 1
      unless room['mood'].nil?
        room['mood'].each do | mood |
	  rooms[room['name']]['mood'][mood] = 'FmP' + m.to_s
	  rooms[room['name']]['learnmood'][mood] = 'FsP' + m.to_s
          #Add any mood aliases as copies with the same mood code
          if room.has_key?('aliases') and room['aliases'].has_key?('mood') and room['aliases']['mood'].has_key?(mood)
            room['aliases']['mood'][mood].each do | aliasname |
              rooms[room['name']]['mood'][aliasname] = 'FmP' + m.to_s
              rooms[room['name']]['learnmood'][aliasname] = 'FsP' + m.to_s
            end
          end
	  m += 1
	end
      end
      r += 1
      # Duplicate room for any aliases
      if room.has_key?('aliases') and room['aliases'].has_key?('room')
        room['aliases']['room'].each do | aliasname |
          rooms[aliasname] = rooms[room['name']].dup
          # Change the name and always exclude from all room commans to avoid double processing
          rooms[aliasname]['name'] = aliasname
          rooms[aliasname]['exclude_room'] = true
          d += 1
        end
      end
    end
    debug and ( "Processed config file from get_rooms is:")    
    debug and ( puts YAML.dump rooms)    
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
      # preset dim levels
      when 'low', 'dim'
        state = 'FdP8'
      when 'mid', 'half'
        state = 'FdP16'
      when 'high', 'bright'
        state = 'FdP24'
      when 'full', 'max', 'maximum'
        state = 'FdP32'        
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
    # Command structure is <transaction number>,<Command>|<Action>|<State><cr>
    if room and device and !device.empty? and state
      '666,!' + room['id'] + room['device'][device] + state + '|Turn ' + room['name'] + ' ' + device + '|' + state + ' via @pauly'
    else
      '666,!' + room['id'] + state + '|Turn ' + room['name'] + '|' + state + ' via @pauly'
    end      
  end

  # Set the Time Zone on the LightWaveRF WiFi Link
  #
  # Example:
  #   >> LightWaveRF.new.timezone
  #
  # Arguments:
  #   debug: (Boolean)
  def timezone debug = false
    command = '666,!FzP' + (Time.now.gmt_offset/60/60).to_s
    debug and ( puts '[Info - LightWaveRF] timezone: command is ' + command )
    data = self.raw command
    debug and ( puts '[Info - LightWaveRF] timezone: response is ' + data )
    return (data == "666,OK\r\n")
  end
  
  # Turn one of your devices on or off or to a particular state
  # Perform action on all devices in a room
  # Perform action on device(s) in all rooms
  #
  # Example:
  #   >> LightWaveRF.new.send 'our', 'light', 'on'
  #   >> LightWaveRF.new.send 'our', 'all', 'off'
  #   >> LightWaveRF.new.send 'all', 'all', '25'
  #
  # Arguments:
  #   room: (String)
  #   device: (String)
  #   state: (String)
  def send room = nil, device = nil, state = 'on', debug = false
    success = false
    debug and (p 'Executing send on device: ' + device + ' in room: ' + room + ' with state: ' + state)
    #debug and ( puts 'config is ' + self.get_config.to_s )
    rooms = self.class.get_rooms self.get_config, debug

    unless rooms[room] and state
      STDERR.puts self.usage
    else
      # support for controlling all rooms (recursive)
      if room == 'all'
        debug and ( p "Processing all rooms..." )
        rooms.each do | config, each_room |
          room = each_room['name']
          unless each_room.has_key?('exclude_room') and each_room['exclude_room']
            p "Room is: " + room
            success = self.send room, device, state, debug
            sleep 1
          else
            p "Skipping excluded room: " + room
          end
        end
        success = true
      # process single room
      else
        debug and ( p "Processing single room..." )
        # support for setting state for all devices in the room (recursive)
        if device == 'all'
          # support for using mood alloff command
          if state == 'fulloff'
            debug and ( p 'Setting all devices off using mood control...' )
            success = self.mood room, 'alloff'
          else
            debug and ( p 'Processing all devices...' )        
            rooms[room]['device'].each do | device_name, code |
              # Check for exclusions
              unless rooms[room]['exclude_device'].has_key?(device_name) and rooms[room]['exclude_device'][device_name]
                debug and ( p "Device is: " + device_name )
                self.send room, device_name, state, debug
                sleep 1
              else
                debug and ( p "Skipping excluded device: " + device_name )
              end
            end
            success = true
          end
        # process single device
        elsif device and rooms[room]['device'][device]
          state = self.class.get_state state
          command = self.command rooms[room], device, state
          debug and ( p 'command is ' + command )
          data = self.raw command
          debug and ( p 'response is ' + data )
          success = true
        else
          STDERR.puts self.usage
        end
      end
    success
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
    success = true
    if self.get_config['sequence'][name]
      self.get_config['sequence'][name].each do | task |
        if task[0] == 'pause'
          debug and ( p 'Pausing for ' + task[1].to_s + ' seconds...' ) 
          sleep task[1]
          debug and ( p 'Resuming...' )
        elsif task[0] == 'mood'
          self.mood task[1], task[2], debug
        else
          self.send task[0], task[1], task[2].to_s, debug          
        end
        sleep 1
      end
      success = true
    end
    success
  end
  
  # Set a mood in one of your rooms
  #
  # Example:
  #   >> LightWaveRF.new.mood 'living', 'movie'
  #
  # Arguments:
  #   room: (String)
  #   mood: (String)
  def mood room = nil, mood = nil, debug = false
    success = false
    debug and (p 'Executing mood: ' + mood + ' in room: ' + room)
    #debug and ( puts 'config is ' + self.get_config.to_s )
    rooms = self.class.get_rooms self.get_config, debug
    # support for setting a mood in all rooms (recursive)
    if room == 'all'
      debug and ( p "Processing all rooms..." )
      rooms.each do | config, each_room |
        room = each_room['name']
        unless each_room.has_key?('exclude_room') and each_room['exclude_room']
          p "Room is: " + room
          success = self.mood room, mood, debug
          sleep 1
        else
          p "Skipping excluded room: " + room
        end
      end
      success = true
    # process single mood
    else
      debug and ( p "Processing single room..." )
      if rooms[room] and mood
        if mood == 'alloff'
          command = self.command rooms[room], nil, 'Fa'
          debug and ( p 'command is ' + command )
          self.raw command
          success = true          
        elsif rooms[room]['mood'][mood]
          command = self.command rooms[room], nil, rooms[room]['mood'][mood]
          debug and ( p 'command is ' + command )
          self.raw command
          success = true
        # deprecated support for other 'allxxx' comands
        elsif mood[0,3] == 'all'
          p 'Support for "mood <room> all<state>" command is deprecated.'
          p 'Please use "<room> all <state>" instead.'
          success = false
        else
          STDERR.puts self.usage
        end
      else
        STDERR.puts self.usage
      end
    end
    success
  end
  
  # Learn a mood in one of your rooms
  #
  # Example:
  #   >> LightWaveRF.new.learnmood 'living', 'movie'
  #
  # Arguments:
  #   room: (String)
  #   mood: (String)
  def learnmood room = nil, mood = nil, debug = false
    debug and (p 'Learning mood: ' + mood)
    #debug and ( puts 'config is ' + self.get_config.to_s )
    rooms = self.class.get_rooms self.get_config, debug
    if rooms[room] and mood and rooms[room]['learnmood'][mood]
      command = self.command rooms[room], nil, rooms[room]['learnmood'][mood]
      debug and ( p 'command is ' + command )
      self.raw command
    else
      STDERR.puts self.usage
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
    # Get host address or broadcast address
    host = self.get_config['host'] || '255.255.255.255'
    # Create socket 
    listener = UDPSocket.new
    # Add broadcast socket options if necessary
    if (host == '255.255.255.255')
      listener.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
    end
    if listener
      # Bind socket to listen for response
      begin
        listener.bind '0.0.0.0',9761
      rescue
        response = "can't bind to listen for a reply"
      end
      # Broadcast command to server
      listener.send(command, 0, host, 9760)
      # Receive response
      if ! response
        response, addr = listener.recvfrom 200
      end
      listener.close
    end
    response
  end
  
  def update_timers past = 60, future = 1440, debug = false
    p '----------------'
    p "Updating timers..."
    require 'net/http'
    require 'rexml/document'
    require 'time'
    require 'date'
      
    # determine the window to query
    now = Time.new
    query_start = now - past.to_i*60
    query_end = now + future.to_i*60
    
    url = LightWaveRF.new.get_config['calendar'] + '?singleevents=true&start-min=' + query_start.strftime( '%FT%T%:z' ).sub('+', '%2B') + '&start-max=' + query_end.strftime( '%FT%T%:z' ).sub('+', '%2B')
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
    
    # if we get a good response
    debug and ( p "Response code is: " + response.code)
    if response.code == '200'
      debug and ( p "Retrieved calendar ok")
      doc = REXML::Document.new response.body
      now = Time.now.strftime '%H:%M'
            
      events = Array.new
      states = Array.new
      
      # refresh the list of entries for the caching period
      doc.elements.each 'feed/entry' do | e |
        debug and ( p "-------------------")
        debug and ( p "Processing entry...")
        event = Hash.new

        # tokenise the title
        debug and (p "Event title is: " + e.elements['title'].text)
        command = e.elements['title'].text.split
        command_length = command.length
        debug and (p "Number of words is: " + command_length.to_s)
        if command and command.length >= 1
          first_word = command[0].to_s
          # determine the type of the entry
          if first_word[0,1] == '#'
            debug and ( p "Type is: state")
            event['type'] = 'state' # temporary type, will be overridden later
            event['room'] = nil
            event['device'] = nil
            event['state'] = first_word[1..-1].to_s
            modifier_start = command_length # can't have modifiers on states
          else
            case first_word
            when 'mood'
              debug and ( p "Type is: mood")
              event['type'] = 'mood'
              event['room'] = command[1].to_s
              event['device'] = nil
              event['state'] = command[2].to_s
              modifier_start = 3
            when 'sequence'
              debug and ( p "Type is: sequence")
              event['type'] = 'sequence'
              event['room'] = nil
              event['device'] = nil
              event['state'] = command[1].to_s
              modifier_start = 2
            else
              debug and ( p "Type is: device")
              event['type'] = 'device'
              event['room'] = command[0].to_s
              event['device'] = command[1].to_s
              # handle optional state
              if command_length > 2
                third_word = command[2].to_s
                first_char = third_word[0,1]
                debug and ( p "First char is: " + first_char)
                # if the third word does not start with a modifier flag, assume it's a state
                if first_char != '@' and first_char != '!' and first_char != '+' and first_char != '-'
                  debug and ( p "State has been given.")
                  event['state'] = command[2].to_s
                  modifier_start = 3
                else
                  debug and ( p "State has not been given.")
                  modifier_start = 2
                end
              else
                debug and ( p "State has not been given.")
                event['state'] = nil
                modifier_start = 2
              end            
            end
          end
          
          # get modifiers if they exist
          time_modifier = 0
          if command_length > modifier_start
            debug and ( p "May have modifiers...")
            when_modifiers = Array.new
            unless_modifiers = Array.new
            modifier_count = command_length - modifier_start
            debug and (p "Count of modifiers is " + modifier_count.to_s)
            for i in modifier_start..(command_length-1)
              modifier = command[i]
              if modifier[0,1] == '@'
                debug and ( p "Found when modifier: " + modifier[1..-1])
                when_modifiers.push modifier[1..-1]
              elsif modifier[0,1] == '!'
                debug and ( p "Found unless modifier: " + modifier[1..-1])
                unless_modifiers.push modifier[1..-1]
              elsif modifier[0,1] == '+'
                debug and ( p "Found positive time modifier: " + modifier[1..-1])
                time_modifier = modifier[1..-1].to_i
              elsif modifier[0,1] == '-'
                debug and ( p "Found negative time modifier: " + modifier[1..-1])
                time_modifier = modifier[1..-1].to_i * -1
              end
            end
            # add when/unless modifiers to the event
            event['when_modifiers'] = when_modifiers
            event['unless_modifiers'] = unless_modifiers
          end          
            
          # parse the date string
          debug and ( p "Time string is: " + e.elements['summary'].text)
          event_time = /When: ([\w ]+) (\d\d:\d\d) to ([\w ]+)?(\d\d:\d\d)&nbsp;\n(.*)<br>(.*)/.match e.elements['summary'].text
          debug and ( p "Event times are: " + event_time.to_s)
          start_date = event_time[1].to_s
          start_time = event_time[2].to_s
          end_date = event_time[3].to_s
          end_time = event_time[4].to_s
          timezone = event_time[5].to_s
          if end_date == '' or end_date.nil? # copy start date to end date if it wasn't given (as the same date)
            end_date = start_date
          end          
          debug and ( p "Start date: " + start_date)
          debug and ( p "Start time: " + start_time)
          debug and ( p "End date: " + end_date)
          debug and ( p "End time: " + end_time)
          debug and ( p "Timezone: " + timezone)

          # convert to datetimes
          start_dt = DateTime.parse(start_date.strip + ' ' + start_time.strip + ' ' + timezone.strip)
          end_dt = DateTime.parse(end_date.strip + ' ' + end_time.strip + ' ' + timezone.strip)

          # apply time modifier if it exists
          if time_modifier != 0
            debug and ( p "Adjusting timings by: " + time_modifier.to_s)
            start_dt = ((start_dt.to_time) + time_modifier*60).to_datetime
            end_dt = ((end_dt.to_time) + time_modifier*60).to_datetime            
          end
          
          debug and ( p "Start datetime: " + start_dt.to_s)
          debug and ( p "End datetime: " + end_dt.to_s)
          
          # populate the dates
          event['date'] = start_dt
          # handle device entries without explicit on/off state
          if event['type'] == 'device' and ( event['state'].nil? or ( event['state'] != 'on' and event['state'] != 'off' ))
            debug and ( p "Duplicating event without explicit on/off state...")
            # if not state was given, assume we meant 'on'
            if event['state'].nil?
              event['state'] = 'on'
            end
            end_event = event.dup # duplicate event for start and end
            end_event['date'] = end_dt
            end_event['state'] = 'off'
            events.push event              
            events.push end_event
          # create state plus start and end events if a state
          elsif event['type'] == 'state'
            debug and ( p "Processing state : " + event['state'])
            # create state
            state = Hash.new
            state['name'] = event['state']
            state['start'] = start_dt.dup
            state['end'] = end_dt.dup
            states.push state
            # convert event to start and end sequence
            event['type'] = 'sequence'
            event['state'] = state['name'] + '_start'
            end_event = event.dup # duplicate event for start and end
            end_event['date'] = end_dt
            end_event['state'] = state['name'] + '_end'
            events.push event              
            events.push end_event
          # else just add the event
          else
            events.push event              
          end
                    
        end
        
      end

      # record some timestamps
      info = Hash.new
      info['updated_at'] = Time.new.strftime( '%FT%T%:z' )
      info['start_time'] = query_start.strftime( '%FT%T%:z' )
      info['end_time'] = query_end.strftime( '%FT%T%:z' )

      # build final timer config
      timers = Hash.new
      timers['info'] = info
      timers['events'] = events
      timers['states'] = states
      
      p 'Timer list is: ' + YAML.dump(timers)
      
      # store the list
      put_timer_cache timers
      self.log_timer_event 'update', nil, nil, nil, true
    
    else
        self.log_timer_event 'update', nil, nil, nil, false
    end
  end     
        
  def run_timers interval = 5, debug = false
    p '----------------'
    p "Running timers..."
    get_timer_cache    
    debug and ( p 'Timer list is: ' + YAML.dump(@timers))
    
    # get the current time and end interval time
    now = Time.new
    start_tm = now - (now.sec)
    end_tm = start_tm + (interval.to_i * 60)
  
    # convert to datetimes
    start_horizon = DateTime.parse(start_tm.to_s)
    end_horizon = DateTime.parse(end_tm.to_s)  
    p '----------------'
    p 'Start horizon is: ' + start_horizon.to_s
    p 'End horizon is: ' + end_horizon.to_s
    
    # sort the events and states (to guarantee order if longer intervals are used)
    @timers['events'].sort! { |x, y| x['date'] <=> y['date'] }
    @timers['states'].sort! { |x, y| x['date'] <=> y['date'] }
    
    # array to hold events that should be executed this run
    run_list = Array.new

    # process each event
    @timers['events'].each do | event |
      debug and ( p '----------------')
      debug and ( p 'Processing event: ' + event.to_s)
      debug and ( p 'Event time is: ' + event['date'].to_s)
      
      # first, assume we'll not be running the event
      run_now = false
      
      # check that it is in the horizon time
      unless event['date'] >= start_horizon and event['date'] < end_horizon
        debug and ( p 'Event is NOT in horizon...ignoring')
      else
        debug and ( p 'Event is in horizon...')
        run_now = true
        
        # if has modifiers, check modifiers against states
        unless event['when_modifiers'].nil?
          debug and ( p 'Event has when modifiers. Checking they are all met...')

          # determine which states apply at the time of the event
          applicable_states = Array.new
          @timers['states'].each do | state |
            if event['date'] >= state['start'] and event['date'] < state['end']
              applicable_states.push state['name']
            end
          end
          debug and ( p 'Applicable states are: ' + applicable_states.to_s)

          # check that each when modifier exists in appliable states
          event['when_modifiers'].each do | modifier |
            unless applicable_states.include? modifier
              debug and ( p 'Event when modifier not met: ' + modifier)
              run_now = false
              break              
            end
          end

          # check that each unless modifier does not exist in appliable states
          event['unless_modifiers'].each do | modifier |
            if applicable_states.include? modifier
              debug and ( p 'Event unless modifier not met: ' + modifier)
              run_now = false
              break              
            end
          end          
        end
        
        # if we have determined the event should run, add to the run list
        if run_now
            run_list.push event
        end        
      end
    end
    
    # process the run list
    p '-----------------------'
    p 'Events to execute this run are: ' + run_list.to_s
    
    triggered = []

    run_list.each do | event |
      # execute based on type
      case event['type']
      when 'mood'
        p 'Executing mood. Room: ' + event['room'] + ', Mood: ' + event['state']
        result = self.mood event['room'], event['state'], debug
        sleep 1
        triggered << [ event['room'], event['device'], event['state'] ]
      when 'sequence'
        p 'Executing sequence. Sequence: ' + event['state']
        result = self.sequence event['state'], debug
        sleep 1
        triggered << [ event['room'], event['device'], event['state'] ]
      else
        p 'Executing device. Room: ' + event['room'] + ', Device: ' + event['device'] + ', State: ' + event['state']
        result = self.send event['room'], event['device'], event['state'], debug        
        sleep 1
        triggered << [ event['room'], event['device'], event['state'] ]        
      end
        self.log_timer_event event['type'], event['room'], event['device'], event['state'], result      
    end

    # update energy log
    title = nil
    text = nil
    if triggered.length > 0
      debug and ( p triggered.length.to_s + ' events so annotating energy log too...' )
      title = 'timer'
      text = triggered.map { |e| e.join " " }.join ", "
    end
    self.energy title, text, debug
    
    self.log_timer_event 'run', nil, nil, nil, true    
  end

end

