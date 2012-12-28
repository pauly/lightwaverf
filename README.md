lightwaverf
===========

LightWaveRF wifi link communication for command line home automation - see http://www.lightwaverf.com

Get a LightWaveRF wifi link http://amzn.to/V7yPPK and a remote socket http://amzn.to/RkukDo

This code unofficial an unaffiliated, please let me know how you get on http://www.clarkeology.com/wiki/lightwaverf

You need a ymlconfig file like the example above, should be fairly clear. If you don't have one the code will create one the first time it runs.

host:
  192.168.0.14
room:
  our:
    - light
    - lights
    - kettle
    - tv
  dining:
    - light
    - lights

Then "pair" your code with your device as normal, put it in pairing mode then turn the device on with the code, with commands like

% lightwaverf our light on

The first time you try to pair a device from the computer look out for the "pair with this device" message on the wifi link lcd screen, and click the button to accept.
