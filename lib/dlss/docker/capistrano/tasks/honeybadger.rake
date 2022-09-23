# frozen_string_literal: true

# Capistrano plugin hook to set default values
namespace :load do
  task :defaults do
    set :honeybadger_use_hooks, fetch(:honeybadger_use_hooks, true)
  end
end

# Integrate hooks into Capistrano
namespace :deploy do
  before :starting, :add_honeybadger_hooks do
    invoke 'honeybadger:add_hooks' if fetch(:honeybadger_use_hooks)
  end
end

namespace :honeybadger do
  task :add_hooks do
    after 'deploy:finishing', 'honeybadger:notify'
  end

  # Replaces honeybadger:deploy to use curl instead of invoking ruby.
  # Adapted from https://github.com/honeybadger-io/honeybadger-ruby/blob/master/vendor/capistrano-honeybadger/lib/capistrano/tasks/deploy.cap
  desc 'Notify Honeybadger of a deploy (using the API via curl)'
  task notify: %i[deploy:set_current_revision] do
    fetch(:honeybadger_server) do
      if (s = primary(:app))
        set(:honeybadger_server, s.select?({ exclude: :no_release }) ? s : nil)
      end
    end

    if (server = fetch(:honeybadger_server))
      revision = fetch(:current_revision)

      on server do |_host|
        info 'Notifying Honeybadger of deploy.'

        honeybadger_config = nil
        within release_path do
          honeybadger_config = capture(:cat, 'config/honeybadger.yml')
        end
        remote_api_key = YAML.safe_load(honeybadger_config)['api_key']
        remote_api_key = capture(:echo, '$HONEYBADGER_API_KEY') if remote_api_key.nil?

        options = {
          'deploy[environment]' => fetch(:honeybadger_env, fetch(:rails_env, 'production')),
          'deploy[local_username]' => fetch(:honeybadger_user, ENV['USER'] || ENV.fetch('USERNAME', nil)),
          'deploy[revision]' => revision,
          'deploy[repository]' => fetch(:repo_url),
          'api_key' => fetch(:honeybadger_api_key, ENV.fetch('HONEYBADGER_API_KEY', nil)) || remote_api_key
        }
        data = options.to_a.map { |pair| pair.join('=') }.join('&')
        execute(:curl, '--no-progress-meter', '--data', "\"#{data}\"", 'https://api.honeybadger.io/v1/deploys')
        info 'Honeybadger notification complete.'
      end
    end
  end
end
