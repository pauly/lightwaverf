require 'test/unit'
require 'lightwaverf'

class LightWaveRFTest < Test::Unit::TestCase

  def test_default_state_on
    assert_equal 'F1', LightWaveRF.get_state
  end

  def test_state_on
    assert_equal 'F1', LightWaveRF.get_state( 'on' )
  end

  def test_state_off
    assert_equal 'F0', LightWaveRF.get_state( 'off' )
  end

  def test_state_percentages
    assert_equal 'FdP3', LightWaveRF.get_state( 10 )
    assert_equal 'FdP8', LightWaveRF.get_state( 25 )
    assert_equal 'FdP16', LightWaveRF.get_state( 50 )
    assert_equal 'FdP24', LightWaveRF.get_state( 75 )
  end

  def test_config_file
    obj = LightWaveRF.new
    obj.set_config_file '/tmp/foo.yml'
    assert_equal '/tmp/foo.yml', obj.get_config_file
  end

  def test_default_config
    obj = LightWaveRF.new
    file = '/tmp/config_' + rand(100).to_s + '.yml'
    if File.exists? file
      File.unlink file
    end
    obj.set_config_file file
    assert /^(\d{1,3}\.){3}\d{1,3}$/.match( obj.get_config['host'] )
    assert obj.get_config['room'].length > 0
    room = obj.get_config['room'].keys.first
    assert obj.get_config['room'][room].length > 0
    File.unlink file
  end

end

