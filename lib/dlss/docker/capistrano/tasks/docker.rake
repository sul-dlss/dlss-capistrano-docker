# frozen_string_literal: true

# Capistrano plugin hook to set default values
namespace :load do
  task :defaults do
    set :docker_prune_use_hooks, fetch(:docker_prune_use_hooks, true)
    set :docker_hub_use_hooks, fetch(:docker_hub_use_hooks, true)
  end
end

# Integrate hooks into Capistrano
namespace :deploy do
  before :starting, :add_docker_hooks do
    invoke 'docker:add_prune_hooks' if fetch(:docker_prune_use_hooks)
    invoke 'docker:add_hub_hooks' if fetch(:docker_hub_use_hooks)
  end
end

namespace :docker do
  task :add_prune_hooks do
    # Cleaning up docker on start so that images/logs are available for troubleshooting.
    after 'deploy:starting', 'docker:prune'
  end

  task :add_hub_hooks do
    after 'deploy:starting', 'docker:login'
    after 'deploy:finishing', 'docker:logout'
  end

  desc 'Log in to Docker Hub'
  task :login do
    on roles(:app) do
      execute(:docker, 'login', '-u', '$DOCKER_USERNAME', '-p', '$DOCKER_PASSWORD')
    end
  end

  desc 'Log out of Docker Hub'
  task :logout do
    on roles(:app) do
      execute(:docker, 'logout')
    end
  end

  desc 'Prune unused images/containers'
  task :prune do
    on roles(:app) do
      execute(:docker, 'system', 'prune', '-af')
    end
  end
end
