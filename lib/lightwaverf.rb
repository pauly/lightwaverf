class LightWaveRF

  @config_file = nil

  def set_config_file file
    @config_file = file
  end

  def get_config_file
    @config_file || File.expand_path('~') + '/lightwaverf-config.yml'
  end

  def get_config
    require 'yaml'
    if ! File.exists? self.get_config_file
      File.open( @config_file, 'w' ) do | handle |
        handle.write YAML.dump( { 'host' => '192.168.0.14', 'room' => { 'our' => [ 'light', 'lights' ] } } )
      end
    end
    YAML.load_file self.get_config_file
  end

  def self.get_rooms config = { 'room' => { }}
    rooms = { }
    r = 1
    config['room'].each do | name, devices |
      rooms[name] = { 'id' => 'R' + r.to_s, 'device' => { }}
      d = 1
      devices.each do | device |
        rooms[name]['device'][device] = 'D' + d.to_s
        d += 1
      end
      r += 1
    end
    rooms
  end

  def self.get_state state = 'on'
    case state
      when 'off'
        state = 'F0'
      when 'on'
        state = 'F1'
      when 1..99
        state = 'FdP' + ( state * 0.32 ).round.to_s
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
    "666,!" + room['id'] + room['device'][device] + state + "|"
  end

  # Turn one of your devices on or off
  #
  # Example:
  #   >> LightWaveRF.new.go 'our', 'light', 'on'
  #
  # Arguments:
  #   room: (String)
  #   device: (String)
  #   state: (String)
  def go room, device, state = 'on', debug = false
    require 'socket'
    config = self.get_config
    debug && ( p 'config is ' + config.to_s )
    rooms = self.class.get_rooms config
    room = rooms[room]
    state = self.class.get_state state
    room && device && state && room['device'][device] || abort( "usage: #{__FILE__} [" + rooms.keys.join( "|" ) + "] light on" )
    command = self.command room, device, state
    debug && ( p 'command is ' + command )
    UDPSocket.new.send command, 0, config['host'], 9760
  end
end
