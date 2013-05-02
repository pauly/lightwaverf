# lightwaverf

LightWaveRF wifi link communication for command line home automation. A ruby gem for lightwaverf home automation. Interact with lightwaverf wifi link from code or the command line. Control your lights, heating, sockets etc. Also set up timers using a google calendar and log energy usage.

Get a LightWaveRF wifi link http://amzn.to/V7yPPK and a remote socket http://amzn.to/RkukDo

Then this code is available as a gem, so:

    gem install lightwaverf

No need to do anything with this repo unless you are particularly interested.

This code unofficial an unaffiliated with http://www.lightwaverf.com, please let me know how you get on http://www.clarkeology.com/wiki/lightwaverf / @pauly

You need a yml config file in your home directory, to build one, if you have already uploaded your data to the LightwaveRF server, download this data by typing

    lightwaverf update 'email@example.com' '1234'

Otherwise, manually specify rooms and devices by typing

    lightwaverf configure

and that will create something like the following.

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
    sudo apt-get install ruby git-core gem
    git clone git://github.com/pauly/lightwaverf.git # you don't need much from here, but have the whole source anyway
    cd lightwaverf && crontab cron.tab # set up the timer and energy monitor
    sudo gem install lightwaverf # or build the gem locally, see below
    lightwaverf configure # or lightwaverf update
    lightwaverf dining lights on # pair one of your devices like you would with any remote control

## how to build the gem from the source
    gem build lightwaverf.gemspec 
    sudo gem install ./lightwaverf-0.3.2.gem # or whatever the latest version is

## how to install the website in this repo on a raspberry pi

  * Install node https://gist.github.com/stolsma/3301813 (it takes an hour or so to build node on the pi.)
  * Then I built in authentication using twitter too, so that the site can be up and running and public, but you'd need to be authenticated to see the usage graphs, so to do that register an app at dev.twitter.com/apps - don't think it matters what you use for any settings but when it's done go to the oauth settings get  the consumer key and consumer secret, copy config/default.sh.sample config/default.sh and paste those values in. Then there are a couple of depencies I think so

    npm install

  * Then start the site with

    source config/default.sh && nohup node app.js &

  * hope that works and the site would then be running on port 3000 on your pi's ip address.

  * Not sure how stable it is but there is a file called "node" in the repo that you can copy into /etc/init.d/ and it should restart the server when the pi restarts. 

## Mood support

Moods are now supported if they are added to the lightwaverf-config.yml file as follows:

    room: 
    - name: living
      device: 
      - light
      mood:
      - movie
      - dinner
      
To set a mood:

    lightwaverf mood living movie
    
You can also execute the special 'alloff' mood to turn off all devices in that room:
    
    lightwaverf mood living alloff
    
To (re)learn a mood with the current device settings:

    lightwaverf mood <room> <mood name>

Note that each receiving device remembers moods independent of the transmitter. i.e. if you have setup moods using a master wall switch, or via the iPhone app, these will already be configured and just need adding to the lightwaverf-config.yml in the right order with a name

Moods are also supported as part of sequences by creating a sequence step as follows:

    sequence:
      testing:
      - - mood
        - living
        - movie

And moods are supported in google calendar timers by creating an event with the following name:

    mood living movie

Note that this will set the mood active at the start time of the event and will not "undo" anything at the end of the event. A separate event should be created to set another mood at another time (e.g. with the special 'alloff' mood)

## Sequence support

Sequences can execute a number of tasks in order, either simple device commands or setting moods, as per the following example:

Note that pauses can be added (in seconds)

    sequence:
      testing:
      - - mood
        - living
        - movie
      - - pause
        - 60
      - - mood
        - living
        - alloff

## how to set up the google calendar timers
  * make yourself a google calendar http://www.google.com/calendar
    * click on my calendars
    * click on "create a new calendar"
    * add some events called "lounge light"
    * put the private address of the calendar into the lightwaverf-config.yml file
    * start the cron jobs with

    crontab cron.tab
    
You can also set moods using the calendar by creating an event with the following syntax:

    mood living movie
    
And you can execute sequences using the calendar by creating an event with the following syntax (where "testing" is the name of the sequence):

    sequence testing
    
If you want to improve any of my docs or code then please fork this and send me a pull request and I'll merge it in.

## history

  * v 0.3   changed the format of the config file, adding configure option, and loading config from lightwavehost.co.uk
  * v 0.3.2 eliminated need to specify WiFi Link IP address (host) in config, added option to update WiFi Link timezone and added ability to turn off all devices in a room

## thanks
thanks to everyone in the lightwaverf community hackers forum http://lightwaverfcommunity.org.uk/forums/forum/lightwaverf-hackers/
