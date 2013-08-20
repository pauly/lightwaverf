# Lightwaverf - Overview

LightWaveRF wifi link communication for command line home automation. A ruby gem for lightwaverf home automation. Interact with lightwaverf wifi link from code or the command line. Control your lights, heating, sockets etc. Also set up timers using a google calendar and log energy usage.

# Setup

Get a LightWaveRF wifi link http://amzn.to/V7yPPK and a remote socket http://amzn.to/RkukDo

## Install gem

Then this code is available as a gem, so:

    gem install lightwaverf

No need to do anything with this repo unless you are particularly interested.

[![Gem Version](https://badge.fury.io/rb/lightwaverf.png)](http://badge.fury.io/rb/lightwaverf)

This code is unofficial and unaffiliated with http://www.lightwaverf.com, please let me know how you get on http://www.clarkeology.com/wiki/lightwaverf / @pauly

## Setup config

You need a yml config file in your home directory, to build one, if you have already uploaded your data to the LightwaveRF server, download this data by typing

    lightwaverf update email@example.com 1234

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
    gem build lightwaverf.gemspec && sudo gem install ./lightwaverf-0.5.0.gem # or whatever the latest version is

## Where did the website in this repo go?

It is now a submodule in the app folder, though I'm not supporting it right. Instead build a simple one pager with:

    lightwaverf summarise && lightwaverf web > /var/www/lightwaverf.html

That presumes you already have a web server running and the document root is /var/www
Here is some sample output: http://pauly.github.io/lightwaverf/

Set up the crontab to rebuild the web page regularly

    # crontab -e
    # rebuild the website every hour, on the hour
    0 * * * * /usr/local/bin/lightwaverf web 5 > /var/www/lightwaverf.html

Todo: make that web page configurable. Any suggestions? If you don't have the energy monitor there is not much on that web page for you right now.

# Usage

## Simple device control

You can set the state of any device with commands such as the following:

    lightwaverf lounge light on
    lightwaverf kitchen spotlights off
    lightwaverf kitchen spotlights 40 (where 40 is 40% - any number between 0 and 100 is valid)
    lightwaverf lounge light dim (alternative for 25%)
    
The following words can be used for quickly setting common levels:

  * 25%: low, dim
  * 50%: mid, half
  * 75%: high, bright
  * 100% full, max, maximum
    
You can also set the state for all devices in a room (based on you configuration file):

    lightwaverf lounge all full (set all configured devices to full)
    lightwaverf kitchen all off (set all configured devices to off)
    
Note that this sets the state on each device configured in that room by looping through the configuration. There will be a short pause between each device being set to ensure that all the commands are successful.
Also note that configured exclusions (see below) will apply when controlling multiple devies

Using the special state 'fulloff' will switch off everything, ignoring exclusions (using the special 'alloff' mood:

    lightwaverf lounge all fulloff (set all configured devices to off, ignoring exclusions)
    
You can also set the state for devices in all rooms (based on you configuration file):

    lightwaverf all all fulloff (switch off all devices in all rooms, ignoring exclusions)
    
Tip: I have found that you can actually pair a single device to 2 different device 'slots' in the same room. So, for example a light could be in slot 1 (D1) and also slot 4 (D4). This allows you to be a bit clever and pair each device to both its own slot and to a 'common' slot, such as this:

    Main light D1 & D4
    Side light D2 & D4
    Spotlights D3 & D4
    
This means that you can set up a 'device' in slot D4 which will actually control all the devices at once. Just remember not to to call it 'all' as this is used as a keyword in the code to do the same thing in a different way as per the above.

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
    
You can also execute the special 'fulloff' mood to turn off all devices in that room:
    
    lightwaverf mood living fulloff
        
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

Note that this will set the mood active at the start time of the event and will not "undo" anything at the end of the event. A separate event should be created to set another mood at another time.

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
        - fulloff

## Aliases

Aliases can be defined for your rooms, devices and moods so that you can use different words to refer to the same entity. For example, you could name a room 'lounge' and setup aliases as 'living' (room) and 'family' (room). You can do the same for devices and moods, as per the following example:

    room: 
    - name: lounge
      device:
      - main
      - floor
      mood:
      - movie
      - dinner
      aliases:
        room:
        - living
        - family
        device:
          main:
          - light
          - central
          floor:
          - lamp
        mood:
          movie:
          - tv
          - television
          
Aliases are particularly useful when using the SiriProxy wrapper (https://github.com/ianperrin/siriproxy-lwrf) to control your devices by voice. The aliases allow you to refer to your rooms, devices and moods using multiple names, so you don't have to recall the exact word and can use more natural language.

## Exclude function

In some cases, you might want to exclude certain rooms or devices from being controlled when you execute 'all' commands. This could be for a number of purposes, including:

  * you have some devices plugged into a LWRF socket that generally need to remain on (but you occasionally want to power-cycle remotely), such as a broadband router
  * you have setup single devices in multiple rooms (to get 'zone' style control) and you want to exclude the 'copies' from commands involving all rooms

In order to exclude entire rooms or devices, you can specify exclusions in your config file for certain rooms as follows:

    room: 
    - name: lounge
      device:
      - main
      - floor
      exclude:
        room: true

This would exclude the room called 'lounge' from commands directed at all rooms.

    room: 
    - name: lounge
      device:
      - main
      - floor
      exclude:
        device:
          floor: true

This would exclude the device called 'floor' from commands directed at all devices in this room and any commands directed at all rooms that involve looping through the device list. Note that this exclusion will not apply to the special 'fulloff' command which will always control all devices in the room, due to the way it works.

# Automated timers (via Google Calendar)

This functionality allows you to create simple or complex schedules to automatically control all your devices (and set moods, run sequences) by simply creating a Google Calendar (gcal) and adding entries to it for the actions you wish to take. You have all the power of gcal's recurrence capabilities to set repeating events.

## How to set up the google calendar timers

  * make yourself a google calendar http://www.google.com/calendar
    * click on "my calendars"
    * click on "create a new calendar"
    * add some events called "lounge light"
    * get the private address address of your calendar by going to calendar settings and clicking on the XML button at the bottom for the private address
    * put this private address of the calendar into the lightwaverf-config.yml file
    * setup crontab (see below)    

## Crontab setup

The timer function utilises 2 separate functions that need scheduling with cron independently:

1) Update Timers - this retrieves the gcal entries for configurable period of time in the future (also a bit in the past, see below), parses them and builds/stores a (yaml) cache file of the events to be considered for exceution. The cache file is lightwave-timer-cache.yml
2) Run Timers - this processes the cache file to actually issue commands via the wifilink

These processes can be scheduled in cron at different rates. It is unlikely that you will need to run the update timers function very often (unless you want to add new entries in the very near future), but the run timers function should be scheduled fairly frequently to make sure that devices are set near to the requested time. I run the update process every 2 hours, and the run process every 5 minutes as follows:

    59 */2 * * * /usr/local/bin/lightwaverf update_timers > /tmp/timer.out
    */5 * * * * /usr/local/bin/lightwaverf run_timers 5 > /tmp/timer.out

Note that following options can be provided to the update_timers function:
    
    lightwaverf update_timers 60 1440 true
    
where:

* 60 is the amount of minutes in the past for which to cache entries (see below for why this is useful)
* 1440 is the amount of minutes in the future to cache entries (essentially define how long you can 'survive' without connectivity to gcal)
* true sets debug mode on if needed

Note that following options must/can be provided to the run_timers function:
    
    lightwaverf run_timers 5 true
    
where:

* 5 is the number of minutes that the cron job is scheduled for. This MUST be provided and must match with the cron expression as the process calculates a window from 'now' for the next X minutes in which any qualifying events will be executed. If this is different to the cron schedule, you will either miss or duplicate events!
* true sets debug mode on if needed

Both functions will log their key activities to lightwaverf-timer.log, so you can check that everything is running ok, and review which devices, moods and sequences were triggered at what times. In the crontab example above, the more detailed logging of either function is sent to /tmp/timer.out from where you can see exactly what happened - switch debug on for more logging.

## Timer usage

Once setup, you can create various entries to control as follows:

    lounge light - this will set the lounge light on (previous dim level) at the start time of the event and turn it off again at the end of the event
    lounge light full - this will set the lounge light to full (100%) at the start time of the event and turn it off again at the end of the event
    lounge all 50 - this will set all the lights in the lounge light to 50% at the start time of the event and turn them off again at the end of the event    
    lounge light on - this will set the lounge light on at the start time of the event and WILL NOT turn it off again at the end of the event
    lounge light off - this will set the lounge light off at the start time of the event and WILL NOT turn it off again at the end of the event    
    
You can also set moods using the calendar by creating an event with the following syntax:

    mood living movie - set movie mode in the lounge
    
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

You can also adjust the run time of the event by a random number of minutes as follows:

    lounge light random 60 - this will adjust the start/end times of the event randomly within the 60 minutes around the actual gcal entry time (ie plus or minus 30 minutes)

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

## Timer Known issues/future improvements

* Issue: Does not currently support "all-day" events created in Google Calendar - can be worked around by always specifying start/end times, even if they are 00:00. (This needs some more work on the regex that parses the dates and times from the gcal feed)
* Improvement: The regex for parsing dates and times from the gcal feed needs to be improved and tightened up
* Improvement: Possibly add some info about which states are currently applicable to the timer log

# History

  * v 0.6.1 fixed timezone issue
  * v 0.6   randomised timers
  * v 0.5   build a web page
  * v 0.4   super timers!
  * v 0.3   changed the format of the config file, adding configure option, and loading config from lightwavehost.co.uk
  * v 0.3.2 eliminated need to specify WiFi Link IP address (host) in config, added option to update WiFi Link timezone and added ability to turn off all devices in a room

# Thanks

thanks to everyone in the lightwaverf community hackers forum http://lightwaverfcommunity.org.uk/forums/forum/lightwaverf-hackers/

If you want to improve any of my docs or code then please fork this and send me a pull request and I'll merge it in.

