# lightwaverf

LightWaveRF wifi link communication for command line home automation. A ruby gem for lightwaverf home automation. See http://www.lightwaverf.com

Get a LightWaveRF wifi link http://amzn.to/V7yPPK and a remote socket http://amzn.to/RkukDo

Then this code is available as a gem, so:

    gem install lightwaverf

No need to do anything with this repo unless you are particularly interested.

This code unofficial an unaffiliated, please let me know how you get on http://www.clarkeology.com/wiki/lightwaverf

You need a yml config file in your home directory, to build one type

    lightwaverf configure

and that will create something like

    host:
      192.168.1.64
    room: 
    - name: our
      device: 
      - light
      - lights
    - name: dining
      device:
      - light
      - lights

That needs to be valid yml so the spacing etc is important.

Then "pair" your code with your device as normal, put it in pairing mode then turn the device on with the code, with commands like

    lightwaverf lounge light on

The first time you try to pair a device from the computer look out for the "pair with this device" message on the wifi link lcd screen, and click the button to accept.

## how to install on your raspberry pi
    sudo apt-get update
    sudo apt-get upgrade
    git clone git://github.com/pauly/lightwaverf.git # you don't need much from here, but have the whole source anyway
    cd lightwaverf && crontab cron.tab # set up the timer and energy monitor
    sudo gem install lightwaverf # or build the gem locally, see below
    cp lightwaverf-config.yml ~ && vi ~/lightwaverf-config.yml # and put in your ip address, calendar, rooms, and devices
    lightwaverf dining lights on # pair one of your devices like you would with any remote control

## how to build the gem from the source
    gem build lightwaverf.gemspec 
    sudo gem install ./lightwaverf-0.2.1.gem # or whatever the latest version is

## how to install the website in this repo on a raspberry pi

Install node https://gist.github.com/stolsma/3301813 (it takes an hour or so to build node on the pi.)
Then I built in authentication using twitter too, so that the site can be up and running and public, but you'd need to be authenticated to see the usage graphs, so to do that register an app at dev.twitter.com/apps - don't think it matters what you use for any settings but when it's done go to the oauth settings get  the consumer key and consumer secret, copy config/default.sh.sample config/default.sh and paste those values in. Then there are a couple of depencies I think so

    sudo npm install -g supervisor
    npm install

Then start the site with
    source config/default.sh && nohup node app.js &

hope that works and the site would then be running on port 3000 on your pi's ip address.

Not sure how stable it is but there is a file called "node" in the repo that you can copy into /etc/init.d/ and it should restart the server when the pi restarts. 

## how to set up the google calendar timers
  * make yourself a google calendar http://www.google.com/calendar
    * click on my calendars
    * click on "create a new calendar"
    * add some events called "lounge light
    * put the private address of the calendar into the lightwaverf-config.yml file
    * start the cron jobs with

    crontab cron.tab

If you want to improve any of my docs or code then please fork this and send me a pull request and I'll merge it in.

## thanks
thanks to everyone in the lightwaverf community hackers forum http://lightwaverfcommunity.org.uk/forums/forum/lightwaverf-hackers/
