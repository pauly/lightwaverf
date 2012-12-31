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

  def config_json
    require 'json'
    require 'pp'
    JSON.generate self.get_config
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
    debug && ( p 'config is ' + self.get_config.to_s )
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
    p data
    # /W=(?<usage>\d+),(?<max>\d+),(?<today>\d+),(?<yesterday>\d+)/.match( data ) # ruby 1.9 only?
    match = /W=(\d+),(\d+),(\d+),(\d+)/.match( data )
    { 'usage' => match[0], 'max' => match[1], 'today' => match[2], 'yesterday' => match[3] }
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

end
