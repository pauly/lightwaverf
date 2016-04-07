sudo apt-get update
sudo apt-get upgrade
sudo apt-get install git-core ruby cnetworkmanager
# ssh-keygen -t rsa -C pauly@clarkeology.com
vi ~/.ssh/id_rsa.pub # and paste into https://github.com/settings/ssh
git clone git://github.com/pauly/lightwaverf.git # or git clone git@github.com:pauly/lightwaverf.git
cd lightwaverf/
sudo gem install lightwaverf
# gem build lightwaverf.gemspec && sudo gem install ./lightwaverf-0.2.1.gem # or whatever the latest version is
# cp lightwaverf-config.yml ~ && vi ~/lightwaverf-config.yml 
lightwaverf configure
lightwaverf dining lights on # and pair this device on your wifi link
