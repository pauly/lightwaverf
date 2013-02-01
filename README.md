# lightwaverf

LightWaveRF wifi link communication for command line home automation - see http://www.lightwaverf.com

Get a LightWaveRF wifi link http://amzn.to/V7yPPK and a remote socket http://amzn.to/RkukDo

Then this code is available as a gem, so:

    gem install lightwaverf

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

    lightwaverf lounge light on

The first time you try to pair a device from the computer look out for the "pair with this device" message on the wifi link lcd screen, and click the button to accept.

## how to install on your raspberry pi
sudo apt-get update
sudo apt-get upgrade
yes | sudo apt-get install git-core ruby
git clone git@github.com:pauly/lightwaverf.git # you don't need much from here, but have the whole source anyway
cd lightwaverf && crontab cron.tab # set up the timer and energy monitor
sudo gem install lightwaverf # or build the gem locally if *say* rubygems.org is down! see below
cp lightwaverf-config.yml && vi ~/lightwaverf-config.yml # and put in your rooms and devices
lightwaverf dining lights on # pair one of your devices like you would with any remote control

## how to build the gem from the source
gem build lightwaverf.gemspec 
sudo gem install ./lightwaverf-0.2.1.gem # or whatever the latest version is
