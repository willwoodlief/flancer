$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "flancer/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "flancer"
  s.version     = Flancer::VERSION
  s.authors     = ["willwoodlief"]
  s.email       = ["willwoodlief@gmail.com"]
  s.homepage    = 'https://gokabam.com/scanners'
  s.summary     = 'Scans for new jobs on Freelancer and gives an api to get info'
  s.description = 'Freelancer has a lot of new jobs opening up but is hard to sort through them'
  s.license     = 'MIT'

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]


  s.add_dependency 'kaminari'
  s.add_dependency 'rails', '~> 5.1.6'
  s.add_dependency 'selenium-webdriver'

  s.add_development_dependency 'figaro'
  s.add_development_dependency 'mysql2'


end







