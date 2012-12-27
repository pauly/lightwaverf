lightwaverf
===========

LightWaveRF wifi link communication for command line home automation.

Get a LightWaveRF wifi link http://amzn.to/V7yPPK and a remote socket http://amzn.to/RkukDo

Please let me know how you get on http://www.clarkeology.com/wiki/lightwaverf

You need a ymlconfig file that looks like this in your home directory, should be fairly clear:

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

Then "pair" your code with your device as normal, put it in pairing mode then turn the device on with the code, with a command like

% bin/lightwaverf our light on

Dimming and moods, still to be done.
