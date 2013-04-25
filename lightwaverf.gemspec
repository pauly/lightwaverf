Gem::Specification.new do |s|
  s.name        = 'lightwaverf'
  s.version     = '0.4.0'
  s.date        = Time.now.strftime '%Y-%m-%d'
  s.summary     = 'Home automation'
  s.description = 'Interact with lightwaverf wifi link from code or the command line. Control your lights, heating, sockets etc. Also set up timers using a google calendar and log energy usage.'
  s.authors     = [ 'Paul Clarke', 'Ian Perrin' ]
  s.email       = 'pauly@clarkeology.com'
  s.files       = [ 'lib/lightwaverf.rb' ]
  s.homepage    = 'http://www.clarkeology.com/wiki/lightwaverf+ruby'
  s.executables << 'lightwaverf'
  s.executables << 'lightwaverf-config-json'
  # s.add_dependency 'htmlentities', '>= 0.0.0'
end
