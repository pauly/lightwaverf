# TODO:
# All day events without times - need to fix regex
# Make regex better
# Get rid of references in yaml cache file - use dup more? Or does it not matter?
# Cope with events that start and end in the same run?
# Add info about states to timer log

# require 'tzinfo'
require 'yaml'
require 'socket'
require 'net/http'
require 'uri'
require 'net/https'
require 'json'
require 'time'
require 'date'
require 'ri_cal'
include Socket::Constants

class LightWaveRF

  @config_file = nil
  @log_file = nil
  @summary_file = nil
  @timer_log_file = nil
  @config = nil
  @timers = nil
  @time = nil

  def quote name = ''
    name = '"' + name + '"' if name.include? ' '
    name
  end

  def usage room = nil
    rooms = self.class.get_rooms self.get_config
    roomName = self.quote( rooms.values.first['name'].to_s )
    config = 'usage: lightwaverf ' + roomName + ' ' + rooms.values.first['device'].keys.first.to_s + ' on'
    config += ' # where ' + roomName + ' is a room in ' + self.get_config_file.to_s
    if room and rooms[room]
      roomName = self.quote( rooms[room]['name'].to_s )
      config += "\ntry: lightwaverf " + roomName + ' all on'
      rooms[room]['device'].each do | device |
        config += "\ntry: lightwaverf " + roomName + ' ' + device.first.to_s + ' on'
      end
    end
    config
  end

  # For debug timing, why is this so slow?
  def time label = nil
    @time = @time || Time.now
    label.to_s + ' (' + ( Time.now - @time ).to_s + ')'
  end

  # Display help
  def help
    help = self.usage + "\n"
    help += "your rooms, and devices, as defined in " + self.get_config_file + ":\n\n"
    help += YAML.dump self.get_config['room']
    room = self.get_config['room'].first['name'].to_s
    device = self.get_config['room'].first['device'].first['name'].to_s
    help += "\n\nso to turn on " + room + " " + device + " type 'lightwaverf " + self.quote( room ) + " " + self.quote( device ) + " on'\n"
  end

  # Configure, build config file. Interactive command line stuff
  #
  # Arguments:
  #   debug: (Boolean)
  def configure debug = false
    config = self.get_config
    puts 'What is the ip address of your wifi link? (currently "' + self.get_config['host'].to_s + '").'
    puts 'Enter a blank line to broadcast UDP commands (ok to just hit enter here).'
    host = STDIN.gets.chomp
    config['host'] = host if ! host.to_s.empty?
    puts 'What is the address of your calendar ics file? (currently "' + self.get_config['calendar'].to_s + '")'
    puts '(ok to just hit enter here)'
    calendar = STDIN.gets.chomp
    config['calendar'] = calendar if ! calendar.to_s.empty?

    puts 'Do you have an energy monitor? [Y/n]'
    puts '(ok to just hit enter here)'
    monitor = STDIN.gets.chomp.to_s
    if ! monitor.empty?
      puts 'got "' + monitor + '"' if debug
      config['monitor'] = true if monitor.byteslice( 0 ).downcase == 'y'
      puts 'made that into "' + config['monitor'].to_s + '"' if debug
    end

    puts 'Shall we create a web page on this server? (currently "' + self.get_config['web'].to_s + '"). Optional (ok to just hit enter here)'
    web = STDIN.gets.chomp.to_s
    puts 'got "' + web + '"' if debug
    config['web'] = web if ! web.empty?
    config['web'] = '/tmp/lightwaverf_web.html' if config['web'].to_s.empty?
    puts 'going with "' + config['web'].to_s + '"' if debug

    device = 'x'
    while ! device.to_s.empty?
      puts 'Enter the name of a room and its devices, space separated. For example "lounge light socket tv". Enter a blank line to finish.'
      puts 'If you want spaces in room or device name, wrap them in quotes. For example "\'living room' 'tv' 'table lamp\'"'
      puts 'If you already have rooms and devices set up on another lightwaverf app then hit enter here, and "lightwaverf update" first.'
      if device = STDIN.gets.chomp
        parts = device.split ' '
        if !parts.first.to_s.empty? and !parts[1].to_s.empty?
          new_room = parts.shift
          config['room'] ||= [ ]
          found = false
          config['room'].each do | room |
            if room['name'] == new_room
              parts.map! do | device |
                { 'name' => device, 'type' => 'O' }
              end
              room['device'] = parts
              found = true
            end
            debug and ( p 'so now room is ' + room.to_s )
          end
          if ! found
            config['room'].push 'name' => new_room, 'device' => parts, 'mood' => nil
          end
          debug and ( p 'added ' + parts.to_s + ' to ' + new_room.to_s )
        end
      end
    end
    debug and ( p 'end of configure, config is now ' + config.to_s )
    file = self.put_config config

    executable = `which lightwaverf`.chomp
    crontab = []
    crontab << '# new crontab added by `' + executable + ' configure`'

    if config['monitor']
      crontab << '# ' + executable + ' energy monitor check ever minute + summarise every 5'
      crontab << '* * * * * ' + executable + ' energy > /tmp/lightwaverf_energy.out 2>&1'
      crontab << '*/5 * * * * ' + executable + ' summarise 7 > /tmp/lightwaverf_summarise.out 2>&1'
    end

    if config['web']
      crontab << '# ' + executable + ' web page generated every hour'
      webTime = Time.now + 300
      crontab << webTime.strftime('%M * * * *') + ' ' + executable + ' web > ' + config['web'] + ' 2> /tmp/lightwaverf_web.out'
    end

    if config['calendar']
      crontab << '# ' + executable + ' update schedule ONLY ONCE A DAY'
      calendarTime = Time.now + 60
      crontab << calendarTime.strftime('%M %H * * *') + ' ' + executable + ' schedule true > /tmp/lightwaverf_schedule.out 2>&1'
    end

    config['room'].each do | room |
      next unless room['device']
      room['device'].each do | device |
        next unless device['reboot']
        out_file = '/tmp/' + room['name'] + device['name'] + '.reboot.out'
        out_file.gsub! /\s/, ''
        crontab << '@reboot ' + executable + ' ' + room['name'] + ' ' + device['name'] + ' ' + device['reboot'] + ' > ' + out_file + ' 2>&1'
      end
    end
    self.update_cron(crontab, executable)
    'Saved config file ' + file
  end

  def executable
    return `which lightwaverf`.chomp
  end

  def set_timer room, device, state, eventDelta, debug = false
    puts 'settimg timer, room: ' + room + ', device: ' + device + ', state: ' + state + ', time: ' + eventDelta if debug
    cmd = room + ' ' + device + ' ' + state 
    out_file = '/tmp/' + cmd + '-' + eventDelta + '.out'
    out_file.gsub! /\s/, '-'
    eventTime = Time.now + self.class.to_seconds(eventDelta)
    line = eventTime.strftime('%M %H %d %m %w') + ' ' + self.executable + ' ' + cmd + ' > ' + out_file + ' 2>&1 # one off from set_timer DELETE ME'
    puts line if debug
    update_cron [line]
  end

  def update_cron lines = [], idToIgnore = nil
    crontab = `crontab -l`.split(/\n/) || []
    if (idToIgnore)
      crontab = crontab.reject do |line|
        line =~ Regexp.new(Regexp.escape(idToIgnore))
      end
    end
    lines.each do |line|
      crontab << line
    end
    File.open( '/tmp/cron.tab', 'w' ) do |handle|
      handle.write crontab.join("\n") + "\n"
    end
    puts `crontab /tmp/cron.tab`
  end

  def schedule debug = false
    id = 'lwrf_cron'
    executable = `which lightwaverf`.chomp
    if (executable == "")
      executable = File.join(File.dirname(File.dirname(File.expand_path(__FILE__))), 'bin', 'lightwaverf')
      puts 'did not get executable from `which lightwaverf` - do we have ' + executable + '???'
      # executable = '/usr/local/bin/lightwaverf'
    end
    if (!File.exists?(executable))
      puts 'still no, bah, aborting'
      return
    end
    crontab = []
    crontab << '# ' + id + ' new crontab added by `' + executable + ' cron`'

    body = self.calendar_body(debug)

    cals = RiCal.parse_string(body)

    state = ''

    cals.first.events.each do | e |
      event = self.tokenise_event e, debug
      next unless event['type'] == 'state'
      next if event['date'] > Date.today
      next if event['end'] < Date.today
      state = event['state'].to_s
    end

    if state != ''
      crontab << '# we have state modifier "' + state + '" so not including all events ' +id
    end

    debug and (p 'state is ' + state)

    cals.first.events.each do | e |
      event = self.tokenise_event e, debug
      next if event['type'] == 'state'
      event = self.get_modifiers event, debug
      event.delete 'command'
      event.delete 'modifier_start'
      event.delete 'time_modifier'

      match = /UNTIL=(\d+)/.match(event['rrule'].to_s)
      if match
        endDate = DateTime.parse(match[1].to_s)
      end
     
      match = /FREQ=(\w+);COUNT=(\d+)/.match(event['rrule'])
      # FREQ=DAILY;COUNT=8 - need to check for weekly, monthly etc
      if match
        endDate = event['date'] + match[2].to_i
      end
  
      if !event['rrule']
        endDate = event['date']
      end

      if endDate
        next if endDate < Date.today
      end

      unless event['when_modifiers'].empty?
        unless event['when_modifiers'].include?(state)
          debug and ( p state + ' not in when modifiers for ' + event.to_s + ' so skipping' )
          next
        end
      end
      if event['unless_modifiers'].include?(state)
        debug and ( p state + ' is in unless modifiers ' + event.to_s + ' so skipping' )
        next
      end

      if event['type'] == 'device' and event['state'] != 'on' and event['state'] != 'off'
        event['room'] = 'sequence' if event['room'].nil?
        crontab << self.cron_entry(event, executable)
        end_event = event.dup # duplicate event for start and end
        end_event['date'] = event['end']
        end_event['state'] = 'off'
        crontab << self.cron_entry(end_event, executable)
      else
        event['room'] = 'sequence' if event['room'].nil?
        crontab << self.cron_entry(event, executable, true)
      end

    end
    self.update_cron(crontab, id)
  end

  def cron_entry event, executable, extra_debug = false
    id = 'lwrf_cron ' + event['rrule'].to_s + (extra_debug ? ' ' + event.inspect : '')
    event['state'] = 'on' if event['state'].nil?
    cmd = event['room'].to_s + ' ' + event['device'].to_s + ' ' + event['state'].to_s
    out_file = '/tmp/' + cmd + '.out'
    out_file.gsub! /\s/, '-'
    return self.cron_entry_times(event) + ' ' + executable + ' ' + cmd + ' > ' + out_file + ' 2>&1 # ' + id
  end

  def cron_entry_times event
    return event['date'].strftime('%M %H * * *') if event['rrule'] =~ /\AFREQ=DAILY/
    match = /BYDAY=([\w,]+)/.match(event['rrule'])
    return event['date'].strftime('%M %H * * ') + self.rrule_days_of_week(match[1]) if match
    return event['date'].strftime('%M %H %d %m *') if event['date']
    return '# 0 12 * * *';
  end

  def rrule_days_of_week days
    return days.gsub('SU', '0').gsub('MO', '1').gsub('TU', '2').gsub('WE', '3').gsub('TH', '4').gsub('FR', '5').gsub('SA', '6')
  end

  def get_config_file
    @config_file || File.expand_path('~') + '/lightwaverf-config.yml'
  end

  def get_log_file
    @log_file || File.expand_path('~') + '/lightwaverf.log'
  end

  def get_summary_file
    @summary_file || File.expand_path('~') + '/lightwaverf-summary.json'
  end

  def get_timer_log_file
    @timer_log_file || File.expand_path('~') + '/lightwaverf-timer.log'
  end

  def log_timer_event type, room = nil, device = nil, state = nil, result = false
    message = nil
    case type
    when 'update'
      message = '### Updated timer cache'
    when 'run'
      # message = '*** Ran timers'
    when 'sequence'
      message = 'Ran sequence: ' + state
    when 'mood'
      message = 'Set mood: ' + mood + ' in room ' + room
    when 'device'
      message = 'Set device: ' + device + ' in room ' + room + ' to state ' + state
    end
    unless message.nil?
      File.open( self.get_timer_log_file, 'a' ) do | f |
        f.write( "\n" + Time.now.to_s + ' - ' + message + ' - ' + ( result ? 'SUCCESS!' : 'FAILED!' ))
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

  # Write the config file
  def put_config config = { 'room' => [ { 'name' => 'default-room', 'device' => [ 'light' => { 'name' => 'default-device' } ] } ] }
    File.open( self.get_config_file, 'w' ) do | handle |
      handle.write YAML.dump( config )
    end
    self.get_config_file
  end

  # Get the config file, create it if it does not exist
  def get_config
    if ! @config
      if ! File.exists? self.get_config_file
        puts self.get_config_file + ' does not exist - copy lightwaverf-configy.yml from https://github.com/pauly/lightwaverf to your home directory or type "lightwaverf configure"'
        self.put_config
      end
      @config = YAML.load_file self.get_config_file
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

    if ! email && ! pin
      STDERR.puts 'missing email and / or pin'
      STDERR.puts 'usage: lightwaverf update email@email.com 1111'
      return
    end

    # Login to LightWaveRF Host server
    uri = URI.parse 'https://lightwaverfhost.co.uk/manager/index.php'
    http = Net::HTTP.new uri.host, uri.port
    http.use_ssl = true if uri.scheme == 'https'

    # Thanks Fitz http://lightwaverfcommunity.org.uk/forums/topic/pauly-lightwaverf-command-line-not-working/
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    data = 'pin=' + pin + '&email=' + email
    headers = { 'Content-Type'=> 'application/x-www-form-urlencoded' }
    resp, data = http.post uri.request_uri, data, headers

    if resp and resp.body
      rooms = self.get_rooms_from resp.body, debug
      # Update 'room' element in LightWaveRF Gem config file
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
            roomDevices << { 'name' => deviceName, 'type' => variables['gDeviceStatus'][deviceStatusIndex][0] }
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
      debug and ( p variable.to_s )
      if variable[0]
        variables[variable[0]] = variable[1].scan( /"([^"]*)\"/ ).map! do | v | v.pop end
        debug and ( p 'variables[' + variable[0] + '] = ' + variables[variable[0]].to_s )
      end
    end
    debug and ( p '[Info - LightWaveRF Gem] so variables are ' + variables.inspect )
    variables
  end

  # Get a cleaned up version of the rooms and devices from the config file
  def self.get_rooms config = { 'room' => [ ] }, debug = false
    rooms = { }
    r = 1
    config['room'].each do | room |
      room = room.first if room.is_a? Array
      rooms[room['name']] = { 'id' => 'R' + r.to_s, 'name' => room['name'], 'device' => { }, 'mood' => { }, 'learnmood' => { }}
      d = 1
      unless room['device'].nil?
        room['device'].each do | device |
          device = device.first if device.is_a? Array
          device = { 'name' => device } if device.is_a? String
          device['id'] = 'D' + d.to_s
          rooms[room['name']]['device'][device['name']] = device
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
    device = device.to_s
    # Command structure is <transaction number>,<Command>|<Action>|<State><cr>
    if room and device and !device.empty? and state
      '666,!' + room['id'] + room['device'][device]['id'] + state + '|Turn ' + room['name'] + ' ' + device + '|' + state + ' via @pauly'
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
    command = '666,!FzP' + ( Time.now.gmt_offset/60/60 ).to_s
    data = self.raw command, true, debug
    return data == "666,OK\r\n"
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
    debug and ( p self.time 'send' )
    success = false
    debug and ( p 'Executing send on device: ' + device + ' in room: ' + room + ' with ' + ( state ? 'state ' + state : 'no state' ))


    # starting to optionally move some functionality out of here
    alternativeScript = self.get_config['pywaverf']
    if alternativeScript and File.exist?( alternativeScript )
      cmd = "#{alternativeScript} \"#{room}\" \"#{device}\" \"#{state}\" \"#{debug}\""
      debug and ( p cmd )
      p `#{cmd}`
      debug and ( p self.time 'done python' )
      return
    end


    rooms = self.class.get_rooms self.get_config, debug
    debug and ( p self.time 'got rooms' )

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
        debug and ( p self.time 'command is ' + command )
        data = self.raw command
        debug and ( p self.time 'response is ' + data.to_s )
        success = true
        data = self.update_state room, device, state, debug
      else
        STDERR.puts self.usage( room );
      end
    end
    success
  end

  def update_state room, device, state, debug
    update = false
    config = self.get_config
    config['room'].each do | r |
      next unless r['name'] == room
      r['device'].each do | d |
        next unless d['name'] == device
        update = d['state'] != state
        d['state'] = state
      end
    end
    self.put_config config if update
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
    debug and ( p 'Executing mood: ' + mood + ' in room: ' + room )
    rooms = self.class.get_rooms self.get_config
    # support for setting a mood in all rooms (recursive)
    if room == 'all'
      debug and ( p 'Processing all rooms...' )
      rooms.each do | config, each_room |
        room = each_room['name']
        debug and ( p 'Room is: ' + room )
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
            p 'Processing device: ' + device[0].to_s
            self.send room, device[0]['name'], state, debug
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
    debug and ( p 'Learning mood: ' + mood )
    rooms = self.class.get_rooms self.get_config
    if rooms[room] and mood and rooms[room]['learnmood'][mood]
      command = self.command rooms[room], nil, rooms[room]['learnmood'][mood]
      debug and ( p 'command is ' + command )
      self.raw command
    else
      STDERR.puts self.usage( room )
    end
  end

  def energy title = nil, text = nil, debug = false
    debug and text and ( p 'energy: ' + text )
    data = self.raw nil, true, debug
    debug and ( p data )
    match = false
    # {"trans":17903,"mac":"03:0F:DA","time":1452531946,"prod":"pwrMtr","serial":"9EB3FE","router":"4F0500","type":"energy","cUse":1163,"todUse":4680,"yesUse":0}
    begin
      data = JSON.parse data[2, data.length]
      debug and ( p data.inspect )
    rescue
      STDERR.puts 'cannot parse ' + data.to_s
      data = nil
    end
    debug and ( p data )
    if data
      data = {
        'message' => {
          'usage' => data['cUse'],
          # 'max' => 'unused now',
          'today' => data['todUse']
        }
      }
      data['timestamp'] = Time.now.to_s
      if text
        data['message']['annotation'] = { 'title' => title.to_s, 'text' => text.to_s }
      end

      if text
        if self.get_config['spreadsheet']
          spreadsheet = self.get_config['spreadsheet']['url']
          match = /key=([\w-]+)/.match spreadsheet
          debug and ( p match )
          if match
            spreadsheet = match[1]
          end
          debug and ( p 'spreadsheet is ' + spreadsheet )
          if spreadsheet
            require 'google_drive'
            session = GoogleDrive.login self.get_config['spreadsheet']['username'], self.get_config['spreadsheet']['password']
            ws = session.spreadsheet_by_key( spreadsheet ).worksheets[0]
            rows = ws.num_rows
            debug and ( p rows.to_s + ' rows in ' + spreadsheet )
            row = rows + 1
            ws[ row, 1 ] = data['timestamp']
            ws[ row, 2 ] = data['message']['usage']
            ws[ row, 3 ] = data['message']['max']
            ws[ row, 4 ] = data['message']['today']
            ws[ row, 5 ] = data['message']['annotation']['title']
            ws[ row, 6 ] = data['message']['annotation']['text']
            ws.save( )
          end
        else
          debug and ( p 'no spreadsheet in your config file...' )
        end

      end
      debug and ( p data )
      begin
        File.open( self.get_log_file, 'a' ) do | f |
          f.write( data.to_json + "\n" )
        end
        file = self.get_summary_file.gsub 'summary', 'daily'
        data['message']['history'] = self.class.get_json file
        data['message']['history'] = data['message']['history'][-7, 0]
        data['message']
      rescue
        puts 'error writing to log'
      end
    end
  end

  def raw command, listen = false, debug = false
    debug and ( p self.time + ' ' + __method__.to_s + ' ' + command.to_s )
    response = nil
    # Get host address or broadcast address
    host = self.get_config['host'] || '255.255.255.255'
    debug and ( p self.time 'got ' + host )
    # Create socket
    listener = UDPSocket.new
    debug and ( p self.time 'got listener' )
    # Add broadcast socket options if necessary
    if host == '255.255.255.255'
      listener.setsockopt Socket::SOL_SOCKET, Socket::SO_BROADCAST, true
    end
    if listener
      if listen
        # Bind socket to listen for response
        begin
          listener.bind '0.0.0.0', 9761
        rescue StandardError => e
          response = "can't bind to listen for a reply; " + e.to_s
        end
      end
      # Broadcast command to server
      if command
        debug and ( p self.time 'sending...' )
        listener.send command, 0, host, 9760
        debug and ( p self.time 'sent' )
      end
      # Receive response
      if listen and ! response
        debug and ( p self.time 'receiving...' )
        response, addr = listener.recvfrom 200
        debug and ( p self.time 'received' )
      end
      debug and ( p self.time 'closing...' )
      listener.close
      debug and ( p self.time 'closed' )
    end
    debug and ( puts '[Info - LightWaveRF] ' + __method__.to_s + ': response is ' + response.to_s )
    response
  end

  def get_calendar_url debug = false
    url = self.get_config['calendar']
    if ! /\.ics/.match url
      STDERR.puts 'we need ical .ics format now, so using default ' + url + ' for dev'
      STDERR.puts 'This contains my test events, not yours! Add your ical url to your config file'
      url = 'https://www.google.com/calendar/ical/aar79qh62fej54nprq6334s7ck%40group.calendar.google.com/public/basic.ics'
    end
    url
  end

  def request url, debug = false
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
  end

  def set_event_type event, debug = false
    if event['command'].first[0,1] == '#'
      event['type'] = 'state' # temporary type, will be overridden later
      event['room'] = nil
      event['device'] = nil
      event['state'] = event['command'].first[1..-1].to_s
      event['modifier_start'] = event['command'].length # can't have modifiers on states
    else
      case event['command'].first.to_s
      when 'mood'
        event['type'] = 'mood'
        event['room'] = event['command'][1].to_s
        event['device'] = nil
        event['state'] = event['command'][2].to_s
        event['modifier_start'] = 3
      when 'sequence'
        event['type'] = 'sequence'
        event['room'] = nil
        event['device'] = nil
        event['state'] = event['command'][1].to_s
        event['modifier_start'] = 2
      else
        event['type'] = 'device'
        event['room'] = event['command'].first.to_s
        event['device'] = event['command'][1].to_s
        # handle optional state
        if event['command'].length > 2
          first_char = event['command'][2].to_s[0,1]
          # if the third word does not start with a modifier flag, assume it's a state
          if /\w/.match first_char
            event['state'] = event['command'][2].to_s
            event['modifier_start'] = 3
          else
            event['modifier_start'] = 2
          end
        else
          event['state'] = nil
          event['modifier_start'] = 2
        end
      end
    end
    event
  end

  def get_modifiers event, debug = false
    event['time_modifier'] = 0
    event['when_modifiers'] = []
    event['unless_modifiers'] = []
    if event['command'].length > event['modifier_start']
      for i in event['modifier_start']..(event['command'].length-1)
        modifier = event['command'][i]
        if modifier[0,1] == '@'
          # debug and ( p 'Found when modifier: ' + modifier[1..-1] + ' for ' + event['command'].to_s )
          event['when_modifiers'].push modifier[1..-1]
        elsif modifier[0,1] == '!'
          # debug and ( p 'Found unless modifier: ' + modifier[1..-1] + ' for ' + event['command'].to_s )
          event['unless_modifiers'].push modifier[1..-1]
        elsif modifier[0,1] == '+'
          event['time_modifier'] = modifier[1..-1].to_i
        elsif modifier[0,1] == '-'
          event['time_modifier'] = modifier[1..-1].to_i * -1
        end
      end
    end
    event['time_modifier'] += self.class.variance( event['summary'] ).to_i
    if event['time_modifier'] != 0
      event['date'] = (( event['date'].to_time ) + event['time_modifier'] * 60 ).to_datetime
      if event['end']
        event['end'] = (( event['end'].to_time ) + event['time_modifier'] * 60 ).to_datetime
      end
    end
    event
  end

  def tokenise_event e, debug = false
    event = { }
    event['summary'] = e.summary
    event['command'] = event['summary'].split
    event['annotate'] = !( /do not annotate/.match event['summary'] )
    event['date'] = e.dtstart
    event['end'] = e.dtend
    if e.rrule.length > 0
      event['rrule'] = e.rrule.first
      # event['rrules'] = event['rrule'].split(';')
    end
    event = set_event_type event, debug
  end

  def calendar_body debug = false
    url = self.get_calendar_url debug
    debug and ( p url )
    response = self.request url, debug
    if response.code != '200'
      debug and ( p "Response code is: " + response.code)
      url.gsub! 'www', 'calendar'
      debug and ( p url )
      debug and ( p '@todo use the redirect url in the message here instead' )
      response = self.request url, debug
      if response.code != '200'
        debug and ( p 'Response code is still: ' + response.code)
      end
    end
    return response.body
  end

  def update_timers past = 60, future = 1440, debug = false
    p '-- Updating timers...'

    query_start = Time.new - self.class.to_seconds( past )
    query_end = Time.new + self.class.to_seconds( future )

    body = self.calendar_body(debug)

    cals = RiCal.parse_string(body)

    timers = { 'events' => [ ], 'states' => [ ] }

    cals.first.events.each do | e |
      begin
        occurs = e.occurrences(:overlapping => [query_start, query_end])
      rescue StandardError => err
        p err.to_s
        p e.to_s
        occurs = []
      end
      next if occurs.length == 0
      occurs.each do | occurrence |

        event = self.tokenise_event occurrence, debug
        debug and ( p event.inspect )

        event = self.get_modifiers event, debug
        event.delete 'command'
        event.delete 'modifier_start'
        event.delete 'time_modifier'

        # handle device entries without explicit on/off state
        # has a PROBLEM with a calendar event set to turn lights to 50% say - automatically adds an off!
        # fix this with something like
        #   if self.get_state event['state'] ! starts with F

        if event['type'] == 'device' and event['state'] != 'on' and event['state'] != 'off'
          debug and ( p 'Duplicating ' + event['summary'] + ' with ' + ( event['state'] ? 'state ' + event['state'] : 'no state' ))
          event['state'] = 'on' if event['state'].nil?
          end_event = event.dup # duplicate event for start and end
          end_event['date'] = event['end']
          end_event['state'] = 'off'
          timers['events'].push event
          timers['events'].push end_event
        elsif event['type'] == 'state'
          debug and ( p 'Create state ' + event['state'] + ' plus start and end events' )
          state = { }
          state['name'] = event['state']
          state['start'] = event['start'].dup
          state['end'] = event['end'].dup
          timers['states'].push state
          event['type'] = 'sequence'
          event['state'] = state['name'] + '_start'
          end_event = event.dup # duplicate event for start and end
          end_event['date'] = event['end']
          end_event['state'] = state['name'] + '_end'
          timers['events'].push event
          timers['events'].push end_event
        else
          timers['events'].push event
        end

      end

    end

    put_timer_cache timers
    self.log_timer_event 'update', nil, nil, nil, true

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
    p '-- Running timers...'
    get_timer_cache
    debug and ( p 'Timer list is: ' + YAML.dump( @timers ))

    # get the current time and end interval time
    now = Time.new
    start_tm = now - now.sec
    end_tm = start_tm + self.class.to_seconds( interval )

    # convert to datetimes
    start_horizon = DateTime.parse start_tm.to_s
    end_horizon = DateTime.parse end_tm.to_s
    p '-- Start horizon is: ' + start_horizon.to_s
    p 'End horizon is: ' + end_horizon.to_s

    # sort the events and states (to guarantee order if longer intervals are used)
    @timers['events'].sort! { | x, y | x['date'] <=> y['date'] }
    @timers['states'].sort! { | x, y | x['date'] <=> y['date'] }

    # array to hold events that should be executed this run
    run_list = [ ]

    # process each event
    @timers['events'].each do | event |
      debug and ( p '-- Processing event: ' + event.to_s )
      debug and ( p 'Event time is: ' + event['date'].to_s )

      # first, assume we'll not be running the event
      run_now = false

      # check that it is in the horizon time
      if event['date'] >= start_horizon and event['date'] < end_horizon
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
    p '-- Events to execute this run are: ' + run_list.to_s

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
        p 'send ' + event['room'].to_s + ' ' + event['device'].to_s + ' ' + event['state'].to_s + ' ' + debug.to_s
        result = self.send event['room'], event['device'], event['state'], debug
      end
      sleep 1
      triggered << [ event['room'], event['device'].to_s, event['state'] ]
      if event['annotate']
        annotate = true
      end
      self.log_timer_event event['type'], event['room'], event['device'].to_s, event['state'], result
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

  def self.get_json file
    json = { }
    content = self.get_contents file
    begin
      json = JSON.parse content
    rescue
      STDERR.puts 'cannot parse ' + file.to_s
    end
    json
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
      <br />@todo merge this with <a href="https://github.com/pauly/robot-butler">robot butler</a>...
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
    daily = self.class.get_json file
    start_date = 0
    d = nil
    last = 0
    prev = 0
    cut_off_date = ( DateTime.now - days ).to_s
    File.open( self.get_log_file, 'r' ).each_line do | line |
      begin
        line = JSON.parse line
      rescue
        line = nil
      end
      if line and line['timestamp'] and ( last != line['message']['usage'] )
        next if ( cut_off_date > line['timestamp'] )
        new_line = []
        d = line['timestamp'][2..3] + line['timestamp'][5..6] + line['timestamp'][8..9] # compact version of date
        ts = Time.parse( line['timestamp'] ).strftime '%s'
        ts = ts.to_i
        ts = ts - start_date
        if start_date == 0
          # start_date = ts # can't get this delta working
        end
        new_line << ts
        smoothedUsage = line['message']['usage'].to_i
        if last != 0 and prev != 0
          smoothedUsage = ( smoothedUsage + last + prev ) / 3 # average of last 3 readings
        end
        new_line << smoothedUsage
        if line['message']['annotation'] and line['message']['annotation']['title'] and line['message']['annotation']['text']
          new_line << line['message']['annotation']['title']
          new_line << line['message']['annotation']['text']
        end
        data << new_line
        if (( ! daily[d] ) or ( line['message']['today'].to_i > daily[d]['today'].to_i ))
          daily[d] = line['message']
          daily[d].delete 'usage'
        end
        prev = last
        last = line['message']['usage'].to_i
      end
    end
    if data and data.first
      if data.first.first != start_date
        data.first[0] += start_date
      end
    end
    summary_file = self.get_summary_file
    File.open( summary_file, 'w' ) do |file|
      file.write( JSON.pretty_generate( data ))
    end
    File.open( summary_file.gsub( 'summary', 'daily' ), 'w' ) do | file |
      file.write daily.to_json.to_s
    end
    File.open( summary_file.gsub( 'summary', 'daily.' + d ), 'w' ) do | file |
      file.write daily.select { |key| key == daily.keys.last }.to_json.to_s
    end
  end

  # http://lightwaverfcommunity.org.uk/forums/topic/link-no-longer-responding-to-udp-commands-any-advice/page/4/#post-16098
  def firmware debug = true
    self.raw '666,!F*p', true, debug
  end

end
