# lightwaverf

# Overview

LightWaveRF wifi link communication for command line home automation. A ruby gem for lightwaverf home automation. Interact with lightwaverf wifi link from code or the command line. Control your lights, heating, sockets etc. Also set up timers using a google calendar and log energy usage.

# Setup

Get a LightWaveRF wifi link http://amzn.to/V7yPPK and a remote socket http://amzn.to/RkukDo

## Install gem

Then this code is available as a gem, so:

    gem install lightwaverf

No need to do anything with this repo unless you are particularly interested.

This code unofficial an unaffiliated with http://www.lightwaverf.com, please let me know how you get on http://www.clarkeology.com/wiki/lightwaverf / @pauly

## Setup config

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

## Device pairing

Then "pair" your code with your device as normal, put it in pairing mode then turn the device on with the code, with commands like

    lightwaverf lounge light on

The first time you try to pair a device from the computer look out for the "pair with this device" message on the wifi link lcd screen, and click the button to accept.

Note that if you are already using the iPhone/other app, then your device pairings may already be done. The wifilink is a single transmitter from the actual device's perspective - all clients (so your iPhone and PC running this ruby program) are the same thing.

## How to install on your raspberry pi
    sudo apt-get update
    sudo apt-get upgrade
    sudo apt-get install ruby git-core gem
    git clone git://github.com/pauly/lightwaverf.git # you don't need much from here, but have the whole source anyway
    cd lightwaverf && crontab cron.tab # set up the timer and energy monitor
    sudo gem install lightwaverf # or build the gem locally, see below
    lightwaverf configure # or lightwaverf update
    lightwaverf dining lights on # pair one of your devices like you would with any remote control

## How to build the gem from the source
    gem build lightwaverf.gemspec 
    sudo gem install ./lightwaverf-0.3.2.gem # or whatever the latest version is

## How to install the website in this repo on a raspberry pi

  * Install node https://gist.github.com/stolsma/3301813 (it takes an hour or so to build node on the pi.)
  * Then I built in authentication using twitter too, so that the site can be up and running and public, but you'd need to be authenticated to see the usage graphs, so to do that register an app at dev.twitter.com/apps - don't think it matters what you use for any settings but when it's done go to the oauth settings get  the consumer key and consumer secret, copy config/default.sh.sample config/default.sh and paste those values in. Then there are a couple of depencies I think so

    npm install

  * Then start the site with

    source config/default.sh && nohup node app.js &

  * hope that works and the site would then be running on port 3000 on your pi's ip address.

  * Not sure how stable it is but there is a file called "node" in the repo that you can copy into /etc/init.d/ and it should restart the server when the pi restarts. 

# Usage

## Simple device control

You can set the state of any device with commands such as the following:

    lightwaverf lounge light on
    lightwaverf kitchen spotlights off
    lightwaverf kitchen spotlights 40 (where 40 is 40% - any number between 0 and 100 is valid)
    lightwaverf lounge light full (alternative for 100%)
    lightwaverf lounge light high (alternative for 75%)
    lightwaverf kitchen spotlights mid (alternative for 50%)
    lightwaverf lounge light low (alternative for 25%)
    
You can also set the state for all devices in a room (based on you configuration file):

    lightwaverf lounge all full (set all configured devices to full)
    
Note that this sets the state on each device configured in that room by looping through the configuration. There will be a short pause between each device being set to ensure that all the commands are successful.

If you declare the state as 'alloff', the device name is ignored and all devices in that room are switched to off

    lightwaverf lounge light alloff
    
Tip: I have found that you can actually pair a single device to 2 different device 'slots' in the same room. So, for example a light could be in slot 1 (D1) and also slot 4 (D4). This allows you to be a bit clever and pair each device to both its own slot and to a 'common' slot, such as this:

    Main light D1 & D4
    Side light D2 & D4
    Spotlights D3 & D4
    
This means that you can set up a 'device' in slot D6 which will actually control all the devices at once. Just remember not to to call it 'all' or 'alloff' as these are used as keywords in the code to do the same thing in a different way as per the above.

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
    
Finally, you can also set any state for all the devices in the room by prefixing any supported state with 'all':
    
    lightwaverf mood living allon
    lightwaverf mood living allfull
    lightwaverf mood living alllow
    lightwaverf mood living all50
    
Note that this sets the state on each device configured in that room by looping through the configuration. There will be a short pause between each device being set to ensure that all the commands are successful.
    
To (re)learn a mood with the current device settings:

    lightwaverf mood living movie

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

# Automated timers (via Google Calendar)

This functionality allows you to create simple or complex schedules to automatically control all your devices (and set moods, run sequences) by simply creating a Google Calendar (gcal) and adding entries to it for the actions you wish to take. You have all the power of gcal's recurrence capabilities to set repeating events.

## How to set up the google calendar timers

  * make yourself a google calendar http://www.google.com/calendar
    * click on my calendars
    * click on "create a new calendar"
    * add some events called "lounge light"
    * get the private address address of your calendar by going to calendar settings and clicking on the 'XML' button at the bottom for the private address
    * put this private address of the calendar into the lightwaverf-config.yml file
    * setup crontab (see below)    

## Crontab setup

The timer function utilises 2 separate functions that need scheduling with cron independently:

1) Update Timers - this retrieves the gcal entries for configurable period of time in the future (also a bit in the past, see below), parses them and builds/stores a (yaml) cache file of the events to be considered for exceution. The cache file is lightwave-timer-cache.yml
2) Run Timers - this processes the cache file to actually issue commands via the wifilink

These processes can be scheduled in cron at different rates. It is unlikely that you will need to run the update timers function very often (unless you want to add new entries in the very near future), but the run timers function should be scheduled fairly frequently to make sure that devices are set near to the requested time. I run the update process every 2 hours, and the run process every 5 minutes as follows:

    59 */2 * * * /usr/local/rvm/gems/ruby-1.9.3-p385/bin/lightwaverf update_timers > /tmp/timer.out
    */5 * * * * /usr/local/rvm/gems/ruby-1.9.3-p385/bin/lightwaverf run_timers 5 > /tmp/timer.out

Note that following options can be provided to the update_timers function:
    
    update_timers 60 1440 true
    
where:

* 60 is the amount of minutes in the past for which to cache entries (see below for why this is useful)
* 1440 is the amount of minutes in the future to cache entries (essentialyl define how long you can 'survive' without connectivity to gcal)
* true sets debug mode on if needed

Note that following options must/can be provided to the run_timers function:
    
    run_timers 5 true
    
where:

* 5 is the number of minutes that the cron job is scheduled for. This MUST be provided and must match with the cron expression as the process calculates a window from 'now' for the next X minutes in which any qualifying events will be executed. If this is different to the cron schedule, you will either miss or duplicate events!
* true sets debug mode on if needed

Both functions will log their key activities to lightwaverf-timer.log, so you can check that everything is running ok, and review which devices, moods and sequences were triggered at what times. In the crontab example above, the more detailed logging of either function is sent to /tmp/timer.out from where you can see exactly what happened - switch debug on for more logging.

## Timer usage

Once setup, you can create various entries to control as follows:

    lounge light - this will set the lounge light on (previous dim level) at the start time of the event and turn it off again at the end of the event
    lounge light full - this will set the lounge light to full (100%) at the start time of the event and turn it off again at the end of the event
    lounge light on - this will set the lounge light on at the start time of the event and WILL NOT turn it off again at the end of the event
    lounge light off - this will set the lounge light off at the start time of the event and WILL NOT turn it off again at the end of the event    
    
You can also set moods using the calendar by creating an event with the following syntax:

    mood living movie - set movie mode in the lounge
    mood living alloff - turn everything off in the lounge
    mood living allon - turn everything on in the lounge
    mood all alloff - turn everything off in all rooms
    
And you can execute sequences using the calendar by creating an eventas follows:

    sequence sunset - run the sequence called 'sunset' in your configuration

## States

States offer a way of getting greater flexibility to manage your devices. Essentially, you can create a special gcal entry that sets a state for the period that that entry covers. You can then make other events dependent on that state either being true or false.

Firstly, define a state be creating a one-word gcal entry starting with a '#':

    #holiday
    
When the start time is reached for this state, any sequence named 'holiday_start' will be executed (if one exists). This is useful for turning everything off automatically when you go on holiday.

When the end time is reached for this state, any sequence named 'holiday_end' will be executed (if one exists).

You can then make events dependent on the state by adding modifiers to the title of the event:

    lounge light on @holiday - this will only run if the 'holiday' state is true when the event time is reached
    lounge light on !holiday - this will run only if the 'holiday' state is NOT true when the event time is reached
    lounge light on @holiday !winter - this will only run if the 'holiday' state is true AND the 'winter' state is NOT true
    
You can use any number of modifiers which will all be considered with AND boolean logic (i.e. every condition must be met)

Note that all-day events are not currently supported, so your states (and all events for that matter) will need to define a start and end time.

## Other modifiers

You can also adjust the run time of the event (relative to the actual gcal event time) by a number of minutes as follows:

    lounge light on +60 - this will adjust the start/end times of the event 60 minutes later than the actual gcal entry time
    lounge light on -30 - this will adjust the start/end times of the event 30 minutes earlier than the actual gcal entry time
    
Note that this is useful when using sunset/sunrise based timers (see below)

Also note that you can only modify the time within the caching time you setup in the cron job for update timers. i.e. you cannot modify an event ahead by 2 hours but only cache historically by 1 hour, as the event will have been purged from the cache by the time you want it run. You will have to configure the caching period on the update timers function to be at least as 'wide' as the biggest time modifier you are using.

## Sunset/sunrise

In order to trigger events based on local sunset/sunrise, you can play a neat trick with the "if this then that" service (www.ifttt.com). Essentially, you can set up a daily job that will automatically create a gcal entry at the start of each day where the start time is the local sunset or sunrise. I use this to create and entry daily which runs a certain sequence. See this IFTTT recipe as an example: https://ifttt.com/recipes/96584

In conjunction with the time modifiers above, you can schedule events to occur relative to the local sunset/sunrise - e.g do something one hour after sunset.
    
## Some example timer use cases

Here are some ideas on things to automate with the timers:

* Switch on children's night-light just before their bedtime, or when sunset occurs (which ever is earlier), and off again in the morning when they are 'allowed' to get up! (This can be achieved by having one event to tutn on/off at fixed times, and then another linked to sunset (using the ifttt recipe above) - whichever happens first will switch the light on and the other will do nothing)
* Set some security lights to switch on/off only when you are on holiday (This can be done by adding a modifier to the event, and then creating up matching 'state' event each time you go away)
* Set your electric blanket to switch on for an hour before bedtime, but only in winter (Create recurring states in sync with the seasons - note that all-day events are not currently supported, so a start/end time must be used)
* Shut everything off at midnight unless there's a party going on (Should be obvious how to do this now!)
* Time your plugin air freshners to switch on/off throughout the day

## Timer kKnown issues/future improvements

* Issue: Does not currently support "all-day" events created in Google Calendar - can be worked around by always specifying start/end times, even if they are 00:00. (This needs some more work on the regex that parses the dates and times from the gcal feed)
* Improvement: The regex for parsing dates and times from the gcal feed needs to be improved and tightened up
* Improvement: Possibly add some info about which states are currently applicable to the timer log
* Improvement: Consider adding a 'random' time shift modifier to make holiday security lights more 'realistic'

# History

  * v 0.3   changed the format of the config file, adding configure option, and loading config from lightwavehost.co.uk
  * v 0.3.2 eliminated need to specify WiFi Link IP address (host) in config, added option to update WiFi Link timezone and added ability to turn off all devices in a room

# Thanks

thanks to everyone in the lightwaverf community hackers forum http://lightwaverfcommunity.org.uk/forums/forum/lightwaverf-hackers/

If you want to improve any of my docs or code then please fork this and send me a pull request and I'll merge it in.

