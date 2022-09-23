# frozen_string_literal: true

# Capistrano plugin hook to set default values
namespace :load do
  task :defaults do
    set :docker_compose_file, fetch(:docker_compose_file, 'docker-compose.yml')

    set :docker_compose_migrate_use_hooks, fetch(:docker_compose_migrate_use_hooks, true)
    set :migration_role, fetch(:migration_role, :db)
    set :migration_servers, -> { primary(fetch(:migration_role)) }
    set :migration_command, fetch(:migration_command, 'db:migrate')

    set :docker_compose_seed_use_hooks, fetch(:docker_compose_seed_use_hooks, false)
    set :seed_command, fetch(:migration_command, 'db:seed')

    set :docker_compose_build_use_hooks, fetch(:docker_compose_build_use_hooks, true)
    set :build_roles, fetch(:build_roles, [:app])
    set :dereference_files, fetch(:dereference_files)
    set :dereference_dirs, fetch(:dereference_dirs, [])

    set :docker_compose_rabbitmq_use_hooks, fetch(:docker_compose_rabbit_use_hooks, false)
    set :rabbitmq_role, fetch(:rabbitmq_role, :app)
    set :rabbitmq_servers, -> { primary(fetch(:rabbitmq_role)) }
    set :rabbitmq_command, fetch(:rabbitmq_command, 'rabbitmq:setup')

    set :docker_compose_restart_use_hooks, fetch(:docker_compose_restart_use_hooks, true)

    set :copy_assets_role, fetch(:copy_assets_role, :app)
    set :assets_path, fetch(:assets_path, 'public/assets')
    set :docker_compose_copy_assets_use_hooks, fetch(:docker_compose_copy_assets_use_hooks, true)
  end
end

# Integrate hooks into Capistrano
namespace :deploy do
  before :starting, :add_docker_hooks do
    invoke 'docker_compose:add_migrate_hooks' if fetch(:docker_compose_migrate_use_hooks)
    invoke 'docker_compose:add_seed_hooks' if fetch(:docker_compose_seed_use_hooks)
    invoke 'docker_compose:add_build_hooks' if fetch(:docker_compose_build_use_hooks)
    invoke 'docker_compose:add_rabbitmq_hooks' if fetch(:docker_compose_rabbitmq_use_hooks)
    invoke 'docker_compose:add_restart_hooks' if fetch(:docker_compose_restart_use_hooks)
    invoke 'docker_compose:add_copy_assets_hooks' if fetch(:docker_compose_copy_assets_use_hooks)
  end
end

namespace :docker_compose do
  task :add_migrate_hooks do
    after 'deploy:publishing', 'docker_compose:migrate'
  end

  task :add_seed_hooks do
    after 'deploy:publishing', 'docker_compose:seed'
  end

  task :add_build_hooks do
    after 'deploy:updating', 'docker_compose:build'
  end

  task :add_rabbitmq_hooks do
    after 'deploy:publishing', 'docker_compose:setup_rabbitmq'
  end

  task :add_restart_hooks do
    after 'deploy:publishing', 'docker_compose:restart'
  end

  task :add_copy_assets_hooks do
    after 'deploy:publishing', 'docker_compose:copy_assets'
  end

  desc 'Migrate database'
  task :migrate do
    on fetch(:migration_servers) do
      within current_path do
        execute(:docker, 'compose', '-f', fetch(:docker_compose_file), 'run', 'app', 'bin/rails',
                fetch(:migration_command))
      end
      info 'Db migrated'
    end
  end

  desc 'Seed database'
  task :seed do
    on fetch(:migration_servers) do
      within current_path do
        execute(:docker, 'compose', '-f', fetch(:docker_compose_file), 'run', 'app', 'bin/rails',
                fetch(:seed_command))
      end
      info 'Db migrated'
    end
  end

  desc 'Build images'
  # Docker build does not dereference symlinks.
  task build: [:dereference_linked_files, :dereference_linked_dirs] do
    on roles(fetch(:build_roles)) do
      info 'Building images'
      within release_path do
        execute(:docker, 'compose', '-f', fetch(:docker_compose_file), 'build')
      end
      info 'Docker images built'
    end
  end

  desc 'Setup RabbitMQ'
  task :setup_rabbitmq do
    on fetch(:rabbitmq_servers) do
      within current_path do
        execute(:docker, 'compose', '-f', fetch(:docker_compose_file), 'run', 'app', 'bin/rake',
                fetch(:rabbitmq_command))
      end
      info 'RabbitMQ setup'
    end
  end

  desc 'Restart containers (down then up)'
  task restart: [:down, :up]

  desc 'Start containers'
  task :up do
    on roles(:app) do |server|
      cmd = cmd_with_profiles(server)
      cmd.concat(['up', '-d'])
      within current_path do
        execute(*cmd)
        info 'Containers started'
      end
    end
  end

  desc 'Tear down containers'
  task :down do
    on roles(:app) do |server|
      cmd = cmd_with_profiles(server)
      cmd.concat(['down'])
      within current_path do
        execute(*cmd)
        info 'Containers down'
      end
    end
  end

  desc 'Copy assets'
  task :copy_assets do
    assets_path = fetch(:assets_path)
    on roles(fetch(:copy_assets_role)) do
      within current_path do
        # Can't do a direct copy to public/assets because it is a symlink.
        execute(:docker, 'compose', '-f', fetch(:docker_compose_file), 'cp',
                'app:/app/public/assets', '.')
        execute(:rm, '-fr', "#{assets_path}/*")
        execute(:mkdir, assets_path)
        execute(:cp, 'assets/*', "#{assets_path}/")
      end
      info 'Assets copied'
    end
  end

  desc 'Dereference linked files'
  task :dereference_linked_files do
    dereference_files = fetch(:dereference_files) || fetch(:linked_files, [])
    next if dereference_files.empty?

    on roles(fetch(:build_roles)) do
      dereference_files.each do |file|
        target = release_path.join(file)
        source = shared_path.join(file)
        execute :rm, target if test "[ -L #{target} ]"
        execute :cp, source, target
      end
    end
  end

  desc 'Dereference linked directories'
  task :dereference_linked_dirs do
    dereference_dirs = fetch(:dereference_dirs)
    next if dereference_dirs.empty?

    on roles(fetch(:build_roles)) do
      dereference_dirs.each do |dir|
        target = release_path.join(dir)
        source = shared_path.join(dir)
        next unless test "[ -L #{target} ]"

        execute :rm, target
        execute :cp, '-r', source, target
      end
    end
  end

  def cmd_with_profiles(server)
    cmd = [:docker, 'compose', '-f', fetch(:docker_compose_file)]
    server.roles.each do |role|
      cmd.concat(['--profile', role.to_s])
    end
    cmd
  end
end
