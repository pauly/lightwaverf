require 'test/unit'
require File.dirname( __FILE__ ) + '/../lib/lightwaverf.rb'

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

  def test_state_percentage_strings
    assert_equal 'FdP3', LightWaveRF.get_state( '10' )
    assert_equal 'FdP8', LightWaveRF.get_state( '25' )
    assert_equal 'FdP16', LightWaveRF.get_state( '50' )
    assert_equal 'FdP24', LightWaveRF.get_state( '75' )
    assert_equal 'FdP3', LightWaveRF.get_state( '10%' )
    assert_equal 'FdP8', LightWaveRF.get_state( '25%' )
    assert_equal 'FdP16', LightWaveRF.get_state( '50%' )
    assert_equal 'FdP24', LightWaveRF.get_state( '75%' )
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
    assert obj.get_config['room'].length > 0
    room = obj.get_config['room'].first
    assert room['device'].length > 0
    File.unlink file
  end

  def test_get_variables
    obj = LightWaveRF.new
    js = <<-END
      <script type="text/javascript" >
        gUserName = '';var gNoLogin = 0;gEmail ='foo@foo.com';gPin ='1234';var gDeviceNames = ["Light","Lights","TV","Device 4","Device 5","Device 6","Mood 1","Mood 2","Mood 3","All Off","Light","Lights","Device 3","Device 4","Device 5","Device 6","Mood 1","Mood 2","Mood 3","All Off","Device 1","Device 2","Device 3","Device 4","Device 5","Device 6","Mood 1","Mood 2","Mood 3","All Off","Device 1","Device 2","Device 3","Device 4","Device 5","Device 6","Mood 1","Mood 2","Mood 3","All Off","Device 1","Device 2","Device 3","Device 4","Device 5","Device 6","Mood 1","Mood 2","Mood 3","All Off","Device 1","Device 2","Device 3","Device 4","Device 5","Device 6","Mood 1","Mood 2","Mood 3","All Off","Device 1","Device 2","Device 3","Device 4","Device 5","Device 6","Mood 1","Mood 2","Mood 3","All Off","Device 1","Device 2","Device 3","Device 4","Device 5","Device 6","Mood 1","Mood 2","Mood 3","All Off"];var gDeviceStatus = ["D","D","O","I","I","I","m","m","m","o","D","D","I","I","I","I","m","m","m","o","I","I","I","I","I","I","m","m","m","o","I","I","I","I","I","I","m","m","m","o","I","I","I","I","I","I","m","m","m","o","I","I","I","I","I","I","m","m","m","o","I","I","I","I","I","I","m","m","m","o","I","I","I","I","I","I","m","m","m","o"];var gRoomNames = ["Our","Dining","Room 3","Room 4","Room 5","Room 6","Room 7","Room 8"];var gRoomStatus = ["A","A","I","I","I","I","I","I"];var gSequences = [['Sample Sequence','!R1D1F1,00:00:05','!R1D1F0,00:00:05']];var gSettingsArray = ["foo@foo.com","1234","9.00","Birmingham, UK | 52.48,-01.86","GMT    Greenwich Mean Time|0","74:0A:BC:03:0F:DA","1111","foo@foo.com1234"];
var gTimers = [['Sample Sequence','Each MTW___S @ 6:30pm until 31/12/19','!FiP"T201001271834"=!FqP"Sample Sequence",T18:30,S25/01/10,E31/13/19,Dmtwxxxs,W1234l,Mjfmamjjasond','31/12/19 18:30']];
var cksecret = "AAAAAAAA";$.cookie("cksecret"  , "AAAAAAAA" );$.cookie("ckemail"   , "foo@foo.com", { expires: 360} );$.cookie("ckpin"     , "1234" , { expires: 360} );
      </script>
    END
    vars = obj.get_variables_from js, true
    # assert_equal vars['gEmail'], 'foo@foo.com'
    # assert_equal vars['gPin'], '1234'
    assert_equal 'Light', vars['gDeviceNames'][0]
    assert_equal 'Lights', vars['gDeviceNames'][1]
    assert_equal 'TV', vars['gDeviceNames'][2]
    # puts vars.inspect
  end

  def test_get_variables_again
    obj = LightWaveRF.new
    js = <<-END
      <script type="text/javascript" >
        gUserName = '';var gNoLogin = 0;gEmail ='foo@foo.com';gPin ='1234';var gDeviceNames = ["Ceiling","TonyLamp","Dev3","Device 4","Device 5","Device 6","Lowest","All lowish","All high","All Off","AfricaLamp","Dimmer2","CeilingLight","SofaLamp","Device 5","Device 6","All low","Movie","All high","All Off","Mirror","Device 2","Device 3","Device 4","Device 5","Device 6","Mood 1","Mood 2","Mood 3","All Off","Device 1","Device 2","Device 3","Device 4","Device 5","Device 6","Mood 1","Mood 2","Mood 3","All Off","Device 1","Device 2","Device 3","Device 4","Device 5","Device 6","Mood 1","Mood 2","Mood 3","All Off","Device 1","Device 2","Device 3","Device 4","Device 5","Device 6","Mood 1","Mood 2","Mood 3","All Off","Device 1","Device 2","Device 3","Device 4","Device 5","Device 6","Mood 1","Mood 2","Mood 3","All Off","Device 1","Device 2","Device 3","Device 4","Device 5","Device 6","Mood 1","Mood 2","Mood 3","All Off"];var gDeviceStatus["D","D","D","I","I","I","M","M","M","o","D","D","D","D","I","I","M","M","M","o","O","I","I","I","I","I","m","m","m","o","I","I","I","I","I","I","m","m","m","o","I","I","I","I","I","I","m","m","m","o","I","I","I","I","I","I","m","m","m","o","I","I","I","I","I","I","m","m","m","o","I","I","I","I","I","I","m","m","m","o"];var gRoomNames = ["bedroom","Lounge","Bathroom","Room 4","Room 5","Room 6","Room 7","Room 8"];var gRoomStatus = ["A","A","A","I","I","I","I","I"];var gRoomStatus = ["A", "A", "A", "I", "I", "I", "I", "I"];
      </script>
    END
    vars = obj.get_variables_from js, true
    assert_equal 'Ceiling', vars['gDeviceNames'][0]
    assert_equal 'TonyLamp', vars['gDeviceNames'][1]
    assert_equal 'Dev3', vars['gDeviceNames'][2]
    puts vars.inspect
  end

  def test_to_seconds
    assert_equal 60, LightWaveRF.to_seconds( 1 )
    assert_equal 300, LightWaveRF.to_seconds( 5 )
    assert_equal 60, LightWaveRF.to_seconds( '1' )
    assert_equal 300, LightWaveRF.to_seconds( '5' )
    assert_equal 300, LightWaveRF.to_seconds( ' 5 ' )
    assert_equal 60, LightWaveRF.to_seconds( '1m' )
    assert_equal 300, LightWaveRF.to_seconds( '5m' )
    assert_equal 3600, LightWaveRF.to_seconds( '1h' )
    assert_equal 3600, LightWaveRF.to_seconds( '1h' )
    assert_equal 60, LightWaveRF.to_seconds( '60s' )
  end

  def test_variance
    v = LightWaveRF.variance 'this on randomise'
    assert_equal nil, v
    v = LightWaveRF.variance 'this off randon 6'
    assert_equal nil, v
    v = LightWaveRF.variance 'this on random 10'
    assert v != nil
    assert v >= -5
    assert v <= 5
    v = LightWaveRF.variance 'this on randomise 10 more stuff'
    assert v != nil
    assert v >= -5
    assert v <= 5
  end

end

