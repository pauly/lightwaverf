sudo apt-get update
sudo apt-get upgrade
# sudo apt-get install git-core ruby
git clone git://github.com/pauly/lightwaverf.git # or git clone git@github.com:pauly/lightwaverf.git
cd lightwaverf/
crontab cron.tab
sudo gem install lightwaverf
# gem build lightwaverf.gemspec && sudo gem install ./lightwaverf-0.2.1.gem # or whatever the latest version is
cp lightwaverf-config.yml ~ && vi ~/lightwaverf-config.yml 
lightwaverf dining lights on # and pair this device on your wifi link
