module Flancer
  require 'selenium-webdriver'
  class Engine < ::Rails::Engine
    isolate_namespace Flancer
    require 'kaminari'  #requires it to be added in the isolation block
  end
end
