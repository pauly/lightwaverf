lightwaverf
===========

LightWaveRF wifi link communication for command line home automation - see http://www.lightwaverf.com

Get a LightWaveRF wifi link http://amzn.to/V7yPPK and a remote socket http://amzn.to/RkukDo

Then this code is available as a gem, so:

% gem install lightwaverf

No need to do anything with this repo unless you are particularly interested.

This code unofficial an unaffiliated, please let me know how you get on http://www.clarkeology.com/wiki/lightwaverf

You need a ymlconfig file in your home directory. If you don't have one the code will create one the first time it runs.

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

That needs to be valid yml so the spacing etc is important - best check out the sample and edit that. I will add a configurator soon.

Then "pair" your code with your device as normal, put it in pairing mode then turn the device on with the code, with commands like

% lightwaverf lounge light on

The first time you try to pair a device from the computer look out for the "pair with this device" message on the wifi link lcd screen, and click the button to accept.
