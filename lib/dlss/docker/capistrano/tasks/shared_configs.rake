# frozen_string_literal: true

# Capistrano plugin hook to set default values
namespace :load do
  task :defaults do
    set :shared_configs_use_hooks, fetch(:shared_configs_use_hooks, true)
  end
end

# Integrate hooks into Capistrano
namespace :deploy do
  before :starting, :add_shared_configs_hooks do
    invoke 'shared_configs:add_hooks' if fetch(:shared_configs_use_hooks)
  end
end

namespace :shared_configs do
  task :add_hooks do
    before 'deploy:updating', 'shared_configs:update'
  end
end
