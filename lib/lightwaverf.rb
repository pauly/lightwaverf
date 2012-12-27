class LightWaveRF
  def config
    require 'yaml'
    file = File.expand_path('~') + '/lightwaverf-config.yml'
    if ! File.exists? file
      File.open( file, 'w' ) do | handle |
        handle.write YAML.dump( { 'host' => '192.168.0.14', 'room' => { 'our' => [ 'light', 'lights' ] } } )
      end
    end
    YAML.load_file file
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
  def go room, device, state
    require 'socket'
    config = self.config
    rooms = { }
    r = 1
    config['room'].each do | name, devices |
      rooms[name] = {
        'id' => 'R' + r.to_s,
        'device' => { }
      }
      d = 1
      devices.each do | device |
        rooms[name]['device'][device] = 'D' + d.to_s
        d += 1
      end
      r += 1
    end
    room = rooms[room]
    state ||= 'on'
    room && device && state && room['device'][device] || abort( "usage: #{__FILE__} [" + rooms.keys.join( "|" ) + "] light on" )
    case state
      when 'off'
        state = 'F0'
      when 'on'
        state = 'F1'
      when 'setup'
        state = 'F1'
      when 1..99
        # @todo dimming etc
    end
    UDPSocket.new.send "666,!" + room['id'] + room['device'][device] + state + "|", 0, config['host'], 9760
  end
end
