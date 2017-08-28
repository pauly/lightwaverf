Gem::Specification.new do |s|
  s.name        = 'lightwaverf'
  s.version     = '0.15.0'
  s.date        = Time.now.strftime '%Y-%m-%d'
  s.summary     = 'Home automation with lightwaverf'
  s.description = <<-end
    Interact with lightwaverf wifi-link from code or the command line.
    Control your lights, heating, sockets, sprinkler etc.
    Also use ical calendar, for timers, log energy usage, and build a website.
  end
  s.authors     = [ 'Paul Clarke', 'Ian Perrin', 'Julian McLean' ]
  s.email       = 'pauly@clarkeology.com'
  s.files       = [ 'lib/lightwaverf.rb', 'app/views/_graphs.ejs' ]
  s.homepage    = 'http://www.clarkeology.com/project/lightwaverf'
  s.executables << 'lightwaverf'
  s.executables << 'lightwaverf-config-json'
  s.add_runtime_dependency 'htmlentities'
  s.add_runtime_dependency 'ri_cal'
  # s.add_dependency 'yaml'
  # s.add_dependency 'socket'
  # s.add_dependency 'net/http'
  # s.add_dependency 'net/https'
  # s.add_dependency 'uri'
  s.add_runtime_dependency 'json', '~> 1'
  # s.add_dependency 'rexml/document'
end
