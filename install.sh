sudo apt-get update
sudo apt-get upgrade
yes | sudo apt-get install git-core ruby
git clone git@github.com:pauly/lightwaverf.git
cd lightwaverf/
crontab cron.tab
gem build lightwaverf.gemspec 
sudo gem install ./lightwaverf-0.2.1.gem # or whatever the latest version is
vi ~/lightwaverf-config.yml 
lightwaverf dining lights on
