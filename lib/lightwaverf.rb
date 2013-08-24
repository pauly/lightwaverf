# TODO:
# All day events without times - need to fix regex
# Make regex better
# Get rid of references in yaml cache file - use dup more? Or does it not matter?
# Cope with events that start and end in the same run?
# Add info about states to timer log
# Build / update cron job automatically

require 'yaml'
require 'socket'
require 'net/http'
require 'uri'
require 'net/https'
require 'json'
require 'rexml/document'
require 'time'
require 'date'
include Socket::Constants

class LightWaveRF

  @config_file = nil
  @log_file = nil
  @summary_file = nil
  @log_timer_file = nil
  @config = nil
  @timers = nil

  # Display usage info
  def usage room = nil
    rooms = self.class.get_rooms self.get_config
    config = 'usage: lightwaverf ' + rooms.values.first['name'].to_s + ' ' + rooms.values.first['device'].keys.first.to_s + ' on'
    config += ' # where "' + rooms.keys.first.to_s + '" is a room in ' + self.get_config_file.to_s
    if room and rooms[room]
      config += "\ntry: lightwaverf " + rooms[room]['name'].to_s + ' all on'
      rooms[room]['device'].each do | device |
        config += "\ntry: lightwaverf " + rooms[room]['name'].to_s + ' ' + device.first.to_s + ' on'
      end
    end
    config
  end

  # Display help
  def help
    help = self.usage + "\n"
    help += "your rooms, devices, and sequences, as defined in " + self.get_config_file + ":\n\n"
    help += YAML.dump self.get_config['room']
    room = self.get_config['room'].last['name'].to_s
    device = self.get_config['room'].last['device'].last.to_s
    help += "\n\nso to turn on " + room + " " + device + " type \"lightwaverf " + room + " " + device + " on\"\n"
  end

  # Configure, build config file. Interactive command line stuff
  #
  # Arguments:
  #   debug: (Boolean
  def configure debug = false
    config = self.get_config
    # puts 'What is the ip address of your wifi link? (' + self.get_config['host'] + '). Enter a blank line to broadcast UDP commands.'
    # host = STDIN.gets.chomp
    # if ! host.to_s.empty?
    #   config['host'] = host
    # end
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
          config['room'] ||= [ ]
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

  # Summary file getter
  def get_summary_file
    @summary_file || File.expand_path('~') + '/lightwaverf-summary.json'
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
      File.open( self.get_timer_log_file, 'a' ) do | f |
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
        self.update_timers
      end
      @timers = YAML.load_file self.get_timer_cache_file
    end
    @timers
  end

  # Store the timer cache
  def put_timer_cache timers = { 'events' => [ ] }
    File.open( self.get_timer_cache_file, 'w' ) do | handle |
      handle.write YAML.dump( timers )
    end
  end

  def put_config config = { 'room' => [ { 'name' => 'our', 'device' => [ 'light', 'lights' ] } ] }
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
      # fix where device names became arrays somehow
      if @config['room']
        @config['room'].map! do | room |
          room['device'].map! do | device |
            device = device.kind_of?( Array ) ? device[0] : device
          end
          room
        end
      end
    end
    @config
  end

  # Update the LightWaveRF Gem config file from the LightWaveRF Host server
  #
  # Example:
  #   >> LightWaveRF.new.update_config name@example.com, 1234
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
    uri = URI.parse 'https://lightwaverfhost.co.uk/manager/index.php'
    http = Net::HTTP.new uri.host, uri.port
    if uri.scheme == 'https'
        http.use_ssl = true
    end
    data = 'pin=' + pin + '&email=' + email
    headers = { 'Content-Type'=> 'application/x-www-form-urlencoded' }
    resp, data = http.post uri.request_uri, data, headers

    if resp and resp.body
      rooms = self.get_rooms_from resp.body, debug
      # Update 'room' element in LightWaveRF Gem config file
      # config['room'] is an array of hashes containing the room name and device names
      # in the format { 'name' => 'Room Name', 'device' => ['Device 1', Device 2'] }
      if rooms.any?
        config = self.get_config
        config['room'] = rooms
        self.put_config config
        debug and ( p '[Info - LightWaveRF Gem] Updated config with ' + rooms.size.to_s + ' room(s): ' + rooms.to_s )
      else
        debug and ( p '[Info - LightWaveRF Gem] Unable to update config: No active rooms or devices found' )
      end
    else
      debug and ( p '[Info - LightWaveRF Gem] Unable to update config: No response from Host server' )
    end
    self.get_config
  end

  def get_rooms_from body = '', debug = nil
    variables = self.get_variables_from body, debug
    rooms = [ ]
    # Rooms - gRoomNames is a collection of 8 values, or room names
    debug and ( puts variables['gRoomStatus'].inspect )
    variables['gRoomNames'].each_with_index do | roomName, roomIndex |
      # Room Status - gRoomStatus is a collection of 8 values indicating the status of the corresponding room in gRoomNames
      #   A: Active
      #   I: Inactive
      if variables['gRoomStatus'] and variables['gRoomStatus'][roomIndex] and variables['gRoomStatus'][roomIndex][0] == 'A'
        debug and ( puts variables['gRoomStatus'][roomIndex].inspect )
        # Devices - gDeviceNames is a collection of 80 values, structured in blocks of ten values for each room:
        #   Devices 1 - 6, Mood 1 - 3, All Off
        roomDevices = [ ]
        deviceNamesIndexStart = roomIndex * 10
        variables['gDeviceNames'][(deviceNamesIndexStart)..(deviceNamesIndexStart+5)].each_with_index do | deviceName, deviceIndex |
          # Device Status - gDeviceStatus is a collection of 80 values which indicate the status/type of the corresponding device in gDeviceNames
          #   O: On/Off Switch
          #   D: Dimmer
          #   R: Radiator(s)
          #   P: Open/Close
          #   I: Inactive (i.e. not configured)
          #   m: Mood (inactive)
          #   M: Mood (active)
          #   o: All Off
          deviceStatusIndex = roomIndex * 10 + deviceIndex
          if variables['gDeviceStatus'] and variables['gDeviceStatus'][deviceStatusIndex] and variables['gDeviceStatus'][deviceStatusIndex][0] != 'I'
            roomDevices << deviceName
          end
        end
        # Create a hash of the active room and active devices and add to rooms array
        if roomName and roomDevices and roomDevices.any?
          rooms << { 'name' => roomName, 'device' => roomDevices }
        end
      end
    end
    rooms
  end

  # Get variables from the source of lightwaverfhost.co.uk
  # Separated out so it can be tested
  #
  def get_variables_from body = '', debug = nil
    # debug and ( p '[Info - LightWaveRF Gem] body was ' + body.to_s )
    variables = { }
    # Extract JavaScript variables from the page
    #   var gDeviceNames = [""]
    #   var gDeviceStatus = [""]
    #   var gRoomNames = [""]
    #   var gRoomStatus = [""]
    # http://rubular.com/r/UH0H4b4afF
    body.scan( /var (gDeviceNames|gDeviceStatus|gRoomNames|gRoomStatus)\s*=\s*([^;]*)/ ).each do | variable |
      if variable[0]
        variables[variable[0]] = variable[1].scan /"([^"]*)\"/
      end
    end
    debug and ( p '[Info - LightWaveRF Gem] so variables are ' + variables.inspect )
    variables
  end

  # Get a cleaned up version of the rooms and devices from the config file
  def self.get_rooms config = { 'room' => [ ]}, debug = false
    rooms = { }
    r = 1
    config['room'].each do | room |
      debug and ( puts room['name'] + ' = R' + r.to_s )
      rooms[room['name']] = { 'id' => 'R' + r.to_s, 'name' => room['name'], 'device' => { }, 'mood' => { }, 'learnmood' => { }}
      d = 1
      unless room['device'].nil?
        room['device'].each do | device |
          # @todo possibly need to complicate this to get a device name back in here
          debug and ( puts ' - ' + device + ' = D' + d.to_s )
          rooms[room['name']]['device'][device] = 'D' + d.to_s
          d += 1
        end
      end
      m = 1
      unless room['mood'].nil?
        room['mood'].each do | mood |
          rooms[room['name']]['mood'][mood] = 'FmP' + m.to_s
          rooms[room['name']]['learnmood'][mood] = 'FsP' + m.to_s
          m += 1
        end
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
      when 0
        state = 'F0'
      when 'on'
        state = 'F1'
      when 'low'
        state = 'FdP8'
      when 'mid'
        state = 'FdP16'
      when 'high'
        state = 'FdP24'
      when 'full'
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

  # Turn one of your devices on or off or all devices in a room off
  #
  # Example:
  #   >> LightWaveRF.new.send 'our', 'light', 'on'
  #   >> LightWaveRF.new.send 'our', '', 'off'
  #
  # This method was too confusing, got rid of "alloff"
  # it can be done with "[room] all off" anyway
  #
  # Arguments:
  #   room: (String)
  #   device: (String)
  #   state: (String)
  def send room = nil, device = nil, state = 'on', debug = false
    success = false
    debug and ( p 'Executing send on device: ' + device + ' in room: ' + room + ' with state: ' + state )
    rooms = self.class.get_rooms self.get_config, debug

    unless rooms[room] and state
      debug and ( p 'Missing room (' + room.to_s + ') or state (' + state.to_s + ')' );
      STDERR.puts self.usage( room );
    else
      # support for setting state for all devices in the room (recursive)
      if device == 'all'
        debug and ( p 'Processing all devices...' )
        rooms[room]['device'].each do | device_name, code |
          debug and ( p "Device is: " + device_name )
          self.send room, device_name, state, debug
          sleep 1
        end
        success = true
      # process single device
      elsif device and rooms[room]['device'][device]
        state = self.class.get_state state
        command = self.command rooms[room], device, state
        debug and ( p 'command is ' + command )
        data = self.raw command
        debug and ( p 'response is ' + data )
        success = true
      else
        STDERR.puts self.usage( room );
      end
    end
    success
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
          sleep task[1].to_i
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
    rooms = self.class.get_rooms self.get_config
    # support for setting a mood in all rooms (recursive)
    if room == 'all'
      debug and ( p "Processing all rooms..." )
      rooms.each do | config, each_room |
        room = each_room['name']
        debug and ( p "Room is: " + room )
        success = self.mood room, mood, debug
        sleep 1
      end
      success = true
    # process single mood
    else
      if rooms[room] and mood
        if rooms[room]['mood'][mood]
          command = self.command rooms[room], nil, rooms[room]['mood'][mood]
          debug and ( p 'command is ' + command )
          self.raw command
          success = true
        # support for special "moods" via device looping
        elsif mood[0,3] == 'all'
          state = mood[3..-1]
          debug and (p 'Selected state is: ' + state)
          rooms[room]['device'].each do | device |
            p 'Processing device: ' + device[0]
            self.send room, device[0], state, debug
            sleep 1
          end
          success = true
        end
      else
        STDERR.puts self.usage( room );
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
    rooms = self.class.get_rooms self.get_config
    if rooms[room] and mood and rooms[room]['learnmood'][mood]
      command = self.command rooms[room], nil, rooms[room]['learnmood'][mood]
      debug and ( p 'command is ' + command )
      self.raw command
    else
      STDERR.puts self.usage( room )
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
      data = {
        'message' => {
          'usage' => match[1].to_i,
          'max' => match[2].to_i,
          'today' => match[3].to_i
        }
      }
      data['timestamp'] = Time.now.to_s
      if note
        data['message']['annotation'] = { 'title' => title.to_s, 'text' => note.to_s }
      end
      debug and ( p data )
      begin
        File.open( self.get_log_file, 'a' ) do | f |
          f.write( data.to_json + "\n" )
        end
        file = self.get_summary_file.gsub 'summary', 'daily'
        json = self.class.get_contents file
        begin
          data['message']['history'] = JSON.parse json
        rescue => e
          data['message']['error'] = 'error parsing ' + file + '; ' + e.to_s
          data['message']['history_json'] = json
        end
        data['message']
      rescue
        puts 'error writing to log'
      end
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

    # determine the window to query
    now = Time.new
    query_start = now - self.class.to_seconds( past )
    query_end = now + self.class.to_seconds( future )

    # url = LightWaveRF.new.get_config['calendar']
    url = self.get_config['calendar']

    ctz = 'UTC'
    case Time.new.zone
    when 'BST'
      ctz = 'Europe/London'
    else
      p 'time zone is ' + Time.new.zone + ' so look out...'
    end
    url += '?ctz=' + ctz
    if ctz != 'UTC'
      p 'using time zone is ' + ctz + ' so look out...'
    end

    url += '&singleevents=true'
    url += '&start-min=' + query_start.strftime( '%FT%T%:z' ).sub( '+', '%2B' )
    url += '&start-max=' + query_end.strftime( '%FT%T%:z' ).sub( '+', '%2B' )
    debug and ( p url )
    parsed_url = URI.parse url
    http = Net::HTTP.new parsed_url.host, parsed_url.port
    begin
      http.use_ssl = true
    rescue
      debug and ( p 'cannot use ssl, tried ' + parsed_url.host + ', ' + parsed_url.port.to_s )
      url.gsub! 'https:', 'http:'
      debug and ( p 'so fetching ' + url )
      parsed_url = URI.parse url
      http = Net::HTTP.new parsed_url.host
    end
    request = Net::HTTP::Get.new parsed_url.request_uri
    response = http.request request

    # if we get a good response
    debug and ( p "Response code is: " + response.code)
    if response.code == '200'
      debug and ( p "Retrieved calendar ok")
      doc = REXML::Document.new response.body
      now = Time.now.strftime '%H:%M'

      events = [ ]
      states = [ ]

      # refresh the list of entries for the caching period
      doc.elements.each 'feed/entry' do | e |
        debug and ( p '-------------------' )
        debug and ( p 'Processing entry...' )
        event = Hash.new

        # tokenise the title
        debug and ( p 'Event title is: ' + e.elements['title'].text )
        command = e.elements['title'].text.split
        command_length = command.length
        debug and ( p 'Number of words is: ' + command_length.to_s )
        if command and command.length >= 1
          first_word = command[0].to_s
          # determine the type of the entry
          if first_word[0,1] == '#'
            debug and ( p 'Type is: state' )
            event['type'] = 'state' # temporary type, will be overridden later
            event['room'] = nil
            event['device'] = nil
            event['state'] = first_word[1..-1].to_s
            modifier_start = command_length # can't have modifiers on states
          else
            case first_word
            when 'mood'
              debug and ( p 'Type is: mood' )
              event['type'] = 'mood'
              event['room'] = command[1].to_s
              event['device'] = nil
              event['state'] = command[2].to_s
              modifier_start = 3
            when 'sequence'
              debug and ( p 'Type is: sequence' )
              event['type'] = 'sequence'
              event['room'] = nil
              event['device'] = nil
              event['state'] = command[1].to_s
              modifier_start = 2
            else
              debug and ( p 'Type is: device' )
              event['type'] = 'device'
              event['room'] = command[0].to_s
              event['device'] = command[1].to_s
              # handle optional state
              if command_length > 2
                third_word = command[2].to_s
                first_char = third_word[0,1]
                debug and ( p 'First char is: ' + first_char )
                # if the third word does not start with a modifier flag, assume it's a state
                # if first_char != '@' and first_char != '!' and first_char != '+' and first_char != '-'
                if /\w/.match first_char
                  debug and ( p 'State has been given.')
                  event['state'] = command[2].to_s
                  modifier_start = 3
                else
                  debug and ( p 'State has not been given.' )
                  modifier_start = 2
                end
              else
                debug and ( p 'State has not been given.' )
                event['state'] = nil
                modifier_start = 2
              end
            end
          end

          # get modifiers if they exist
          time_modifier = 0
          if command_length > modifier_start
            debug and ( p 'May have modifiers...' )
            when_modifiers = [ ]
            unless_modifiers = [ ]
            modifier_count = command_length - modifier_start
            debug and ( p 'Count of modifiers is ' + modifier_count.to_s )
            for i in modifier_start..(command_length-1)
              modifier = command[i]
              if modifier[0,1] == '@'
                debug and ( p 'Found when modifier: ' + modifier[1..-1] )
                when_modifiers.push modifier[1..-1]
              elsif modifier[0,1] == '!'
                debug and ( p 'Found unless modifier: ' + modifier[1..-1] )
                unless_modifiers.push modifier[1..-1]
              elsif modifier[0,1] == '+'
                debug and ( p 'Found positive time modifier: ' + modifier[1..-1] )
                time_modifier = modifier[1..-1].to_i
              elsif modifier[0,1] == '-'
                debug and ( p 'Found negative time modifier: ' + modifier[1..-1] )
                time_modifier = modifier[1..-1].to_i * -1
              end
            end
            # add when/unless modifiers to the event
            event['when_modifiers'] = when_modifiers
            event['unless_modifiers'] = unless_modifiers
          end

          # parse the date string
          event_time = /When: ([\w ]+) (\d\d:\d\d) to ([\w ]+)?(\d\d:\d\d)&nbsp;\n(.*)<br>(.*)/.match e.elements['summary'].text
          debug and ( p 'Event times are: ' + event_time.to_s )
          start_date = event_time[1].to_s
          start_time = event_time[2].to_s
          end_date = event_time[3].to_s
          end_time = event_time[4].to_s
          timezone = event_time[5].to_s
          if end_date == '' or end_date.nil? # copy start date to end date if it wasn't given (as the same date)
            end_date = start_date
          end

          time_modifier += self.class.variance( e.elements['title'].text ).to_i
          event['annotate'] = ! ( /do not annotate/.match e.elements['title'].text )

          debug and ( p 'Start date: ' + start_date )
          debug and ( p 'Start time: ' + start_time )
          debug and ( p 'End date: ' + end_date )
          debug and ( p 'End time: ' + end_time )
          debug and ( p 'Timezone: ' + timezone )

          # convert to datetimes
          start_dt = DateTime.parse( start_date.strip + ' ' + start_time.strip + ' ' + timezone.strip )
          end_dt = DateTime.parse( end_date.strip + ' ' + end_time.strip + ' ' + timezone.strip )

          # apply time modifier if it exists
          if time_modifier != 0
            debug and ( p 'Adjusting timings by: ' + time_modifier.to_s )
            start_dt = (( start_dt.to_time ) + time_modifier * 60 ).to_datetime
            end_dt = (( end_dt.to_time ) + time_modifier * 60 ).to_datetime
          end

          debug and ( p 'Start datetime: ' + start_dt.to_s )
          debug and ( p 'End datetime: ' + end_dt.to_s )

          # populate the dates
          event['date'] = start_dt
          # handle device entries without explicit on/off state
          if event['type'] == 'device' and ( event['state'].nil? or ( event['state'] != 'on' and event['state'] != 'off' ))
            debug and ( p 'Duplicating event without explicit on/off state...' )
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
            debug and ( p 'Processing state : ' + event['state'] )
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
      info = { }
      info['updated_at'] = Time.new.strftime( '%FT%T%:z' )
      info['start_time'] = query_start.strftime( '%FT%T%:z' )
      info['end_time'] = query_end.strftime( '%FT%T%:z' )

      # build final timer config
      timers = { }
      timers['info'] = info
      timers['events'] = events
      timers['states'] = states

      p 'Timer list is: ' + YAML.dump( timers )

      # store the list
      put_timer_cache timers
      self.log_timer_event 'update', nil, nil, nil, true

    else
      self.log_timer_event 'update', nil, nil, nil, false
    end
  end

  # Return the randomness value that may be in the event title
  def self.variance title = '', debug = nil
    randomness = /random\w* (\d+)/.match title
    if randomness
      n = randomness[1].to_i
      debug and ( p 'randomness is ' + n.to_s )
      return rand( n ) - ( n / 2 )
    end
    debug and ( p 'no randomness return nil' )
    return nil
  end

  # Convert a string to seconds, assume it is in minutes
  def self.to_seconds interval = 0
    match = /^(\d+)([shd])$/.match( interval.to_s )
    if match
      case match[2]
      when 's'
        return match[1].to_i
      when 'h'
        return match[1].to_i * 3600
      when 'd'
        return match[1].to_i * 86400
      end
    end
    return interval.to_i * 60
  end

  def run_timers interval = 5, debug = false
    p '----------------'
    p 'Running timers...'
    get_timer_cache
    debug and ( p 'Timer list is: ' + YAML.dump( @timers ))

    # get the current time and end interval time
    now = Time.new
    start_tm = now - now.sec
    end_tm = start_tm + self.class.to_seconds( interval )

    # convert to datetimes
    start_horizon = DateTime.parse start_tm.to_s
    end_horizon = DateTime.parse end_tm.to_s
    p '----------------'
    p 'Start horizon is: ' + start_horizon.to_s
    p 'End horizon is: ' + end_horizon.to_s

    # sort the events and states (to guarantee order if longer intervals are used)
    @timers['events'].sort! { | x, y | x['date'] <=> y['date'] }
    @timers['states'].sort! { | x, y | x['date'] <=> y['date'] }

    # array to hold events that should be executed this run
    run_list = [ ]

    # process each event
    @timers['events'].each do | event |
      debug and ( p '----------------' )
      debug and ( p 'Processing event: ' + event.to_s )
      debug and ( p 'Event time is: ' + event['date'].to_s )

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
          debug and ( p 'Event has when modifiers. Checking they are all met...' )

          # determine which states apply at the time of the event
          applicable_states = [ ]
          @timers['states'].each do | state |
            if event['date'] >= state['start'] and event['date'] < state['end']
              applicable_states.push state['name']
            end
          end
          debug and ( p 'Applicable states are: ' + applicable_states.to_s )

          # check that each when modifier exists in appliable states
          event['when_modifiers'].each do | modifier |
            unless applicable_states.include? modifier
              debug and ( p 'Event when modifier not met: ' + modifier )
              run_now = false
              break
            end
          end

          # check that each unless modifier does not exist in appliable states
          event['unless_modifiers'].each do | modifier |
            if applicable_states.include? modifier
              debug and ( p 'Event unless modifier not met: ' + modifier )
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

    triggered = [ ]

    annotate = false
    run_list.each do | event |
      # execute based on type
      case event['type']
      when 'mood'
        p 'Executing mood. Room: ' + event['room'] + ', Mood: ' + event['state']
        result = self.mood event['room'], event['state'], debug
      when 'sequence'
        p 'Executing sequence. Sequence: ' + event['state']
        result = self.sequence event['state'], debug
      else
        p 'Executing device. Room: ' + event['room'] + ', Device: ' + event['device'] + ', State: ' + event['state']
        result = self.send event['room'], event['device'], event['state'], debug
      end
      sleep 1
      triggered << [ event['room'], event['device'], event['state'] ]
      if event['annotate']
        annotate = true
      end
      self.log_timer_event event['type'], event['room'], event['device'], event['state'], result
    end

    # update energy log
    title = nil
    text = nil
    if annotate
      debug and ( p triggered.length.to_s + ' events so annotating energy log too...' )
      title = 'timer'
      text = triggered.map { | e | e.join ' ' }.join ', '
    end
    self.energy title, text, debug

    self.log_timer_event 'run', nil, nil, nil, true
  end

  def self.get_contents file
    begin
      file = File.open file, 'r'
      content = file.read
      file.close
    rescue
      STDERR.puts 'cannot open ' + file
    end
    content.to_s
  end

  def build_web_page debug = nil

    rooms = self.class.get_rooms self.get_config
    list = '<dl>'
    rooms.each do | name, room |
      debug and ( puts name + ' is ' + room.to_s )
      list += '<dt><a>' + name + '</a></dt><dd><ul>'
      room['device'].each do | device |
        # link ideally relative to avoid cross domain issues
        link = '/room/' + room['name'].to_s + '/' + device.first.to_s
        list += '<li><a class="ajax off" href="' + link + '">' + room['name'].to_s + ' ' + device.first.to_s + '</a></li>'
      end
      list += '</ul></dd>'
    end
    list += '</dl>'

    summary = self.class.get_contents self.get_summary_file
    js = self.class.get_contents( File.dirname( __FILE__ ) + '/../app/views/_graphs.ejs' ).gsub( '<%- summary %>', summary )
    date = Time.new.to_s
    title = self.get_config.has_key?('title') ? self.get_config['title'] : ( 'Lightwaverf energy stats ' + date )
    intro = <<-end
      Sample page generated #{date} with <code>lightwaverf web</code>.
      Check out <a href="https://github.com/pauly/lightwaverf">the new simplified repo</a> for details
      or <a href="https://rubygems.org/gems/lightwaverf">gem install lightwaverf && lightwaverf web</a>...
      <br />@todo make a decent, useful, simple, configurable web page...
    end
    help = list
    html = <<-end
      <html>
        <head>
          <title>#{title}</title>
          <style type="text/css">
            body { font-family: arial, verdana, sans-serif; }
            div#energy_chart { width: 800px; height: 600px; }
            div#gauge_div { width: 100px; height: 100px; }
            dd { display: none; }
            .off, .on:hover { padding-right: 18px; background: url(lightning_delete.png) no-repeat top right; }
            .on, .off:hover { padding-right: 18px; background: url(lightning_add.png) no-repeat top right; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="row">
              <div class="col">
                <h1>#{title}</h1>
                <p class="intro">#{intro}</p>
                <div id="energy_chart">
                  Not seeing an energy chart here?
                  Maybe not working in your device yet, sorry.
                  This uses google chart api which may generate FLASH :-(
                  Try in a web browser.
                </div>
                <h2>Rooms and devices</h2>
                <p>@todo make these links to control the devices...</p>
                <p class="help">#{help}</p>
                #{js}
              </div>
              <div class="col">
                <div class="col" id="gauge_div"></div>
              </div>
            </div>
          </div>
          <p>By <a href="http://www.clarkeology.com/blog/">Paul Clarke</a>, a work in progress.</p>
        </body>
      </html>
    end
  end

  # summarise the log data for ease of use
  def summarise days = 7, debug = nil
    days = days.to_i
    data = [ ]
      file = self.get_summary_file.gsub 'summary', 'daily'
      json = self.class.get_contents file
      daily = JSON.parse json
    start_date = 0
    d = nil
    File.open( self.get_log_file, 'r' ).each_line do | line |
      line = JSON.parse line
      if line and line['timestamp']
        new_line = []
        d = line['timestamp'][2..3] + line['timestamp'][5..6] + line['timestamp'][8..9] # compact version of date
        ts = Time.parse( line['timestamp'] ).strftime '%s'
        ts = ts.to_i
        if start_date > 0
          ts = ts - start_date
        else
          start_date = ts
        end
        new_line << ts
        new_line << line['message']['usage'].to_i / 10
        if line['message']['annotation'] and line['message']['annotation']['title'] and line['message']['annotation']['text']
          new_line << line['message']['annotation']['title']
          new_line << line['message']['annotation']['text']
        end
        data << new_line
        if (( ! daily[d] ) or ( line['message']['today'] > daily[d]['today'] ))
          daily[d] = line['message']
          daily[d].delete 'usage'
        end
      end
    end
    debug and ( puts 'got ' + data.length.to_s + ' lines in the log' )
    data = data.last 60 * 24 * days
    debug and ( puts 'now got ' + data.length.to_s + ' lines in the log ( 60 * 24 * ' + days.to_s + ' = ' + ( 60 * 24 * days ).to_s + ' )' )
    if data and data[0]
      debug and ( puts 'data[0] is ' + data[0].to_s )
      if data[0][0] != start_date
        data[0][0] += start_date
      end
    end
    summary_file = self.get_summary_file
    File.open( summary_file, 'w' ) do |file|
      file.write data.to_s
    end
    # @todo fix the daily stats, every night it reverts to the minimum value because the timezones are different
    # so 1am on the wifi-link looks midnight on the server
    File.open( summary_file.gsub( 'summary', 'daily' ), 'w' ) do | file |
      file.write daily.to_json.to_s
    end
    File.open( summary_file.gsub( 'summary', 'daily.' + d ), 'w' ) do | file |
      file.write daily.select { |key| key == daily.keys.last }.to_json.to_s
    end
  end

end
