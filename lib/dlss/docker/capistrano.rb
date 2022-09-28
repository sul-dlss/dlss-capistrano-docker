# frozen_string_literal: true

require 'capistrano/one_time_key'
require 'capistrano/shared_configs'

Dir.glob("#{__dir__}/capistrano/tasks/*.rake").each { |r| import r }
