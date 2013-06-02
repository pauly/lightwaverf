Gem::Specification.new do |s|
  s.name        = 'lightwaverf'
  s.version     = '0.4.0'
  s.date        = Time.now.strftime '%Y-%m-%d'
  s.summary     = 'Home automation with lightwaverf'
  s.description = <<-end
    Interact with lightwaverf wifi-link from code or the command line.
    Control your lights, heating, sockets etc.
    Also set up timers using a google calendar and log energy usage.
  end
  s.authors     = [ 'Paul Clarke', 'Ian Perrin', 'Julian McLean' ]
  s.email       = 'pauly@clarkeology.com'
  s.files       = [ 'lib/lightwaverf.rb' ]
  s.homepage    = 'http://www.clarkeology.com/wiki/lightwaverf+ruby'
  s.executables << 'lightwaverf'
  s.executables << 'lightwaverf-config-json'
  s.add_dependency 'htmlentities'
  # s.add_dependency 'yaml'
  # s.add_dependency 'socket'
  # s.add_dependency 'net/http'
  # s.add_dependency 'net/https'
  # s.add_dependency 'uri'
  s.add_dependency 'json'
  # s.add_dependency 'rexml/document'
end
