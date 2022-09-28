# dlss-capistrano-docker

[![Gem Version](https://badge.fury.io/rb/dlss-capistrano-docker.svg)](https://badge.fury.io/rb/dlss-capistrano-docker)
[![CircleCI](https://circleci.com/gh/sul-dlss/dlss-capistrano-docker.svg?style=svg)](https://circleci.com/gh/sul-dlss/dlss-capistrano-docker)


This gem provides Capistrano Docker deployment tasks used by Stanford Libraries' Digital Library Systems and Services group.

It requires that the services to be run on a server be specified by a docker compose configuration file.

## Included Tasks
* `ssh`: establishes an SSH connection to the host running in environment, and changes into the current deployment directory.
* `honeybadger:notify`: notifies Honeybadger of deploy using curl (thus, ruby is not required on host).
* `docker:login`: log into Docker Hub. Logging in is required to avoid strict image download limits.
* `docker:logout`: log out of Docker Hub.
* `docker:prune`: prune docker artifacts to avoid filling disk space.
* `docker_compose:migrate`: migrate the database.
* `docker_compose:seed`: seed the database.
* `docker_compose:build`: build images for the services.
* `docker_compose:setup_rabbit`: create channel, queues, etc for RabbitMQ.
* `docker_compose:restart`: down then up services.
* `docker_compose:up`: stop services.
* `docker_compose:down`: tear down services.
* `docker_compose:copy_assets`: copy assets from a container to the server so they can be served by Apache.
* `docker_compose:dereference_linked_files`: turn linked files into actual files.
* `docker_compose:dereference_linked_dirs`: turn linked directories into actual directories containing actual files.

## Hooks
Hooks into the Capistrano lifecycle are provided for most of these tasks. These hooks can be controlled with variables, e.g., `docker_hub_use_hooks` to control the hooks for `docker:login` and `docker:logout`.

In addition to tasks included in this gem, a hook is provided for `shared_configs:update`.

## Usage
For an example of any of the following, see https://github.com/sul-dlss/happy-heron

### `Gemfile`
* Add `gem 'dlss-capistrano-docker', require: false` to the deployment group.
* Remove any gems that are removed from `Capfile` below.
* Move puma gem from development/test dependencies to the application dependencies. (Puma will be used as the application server instead of Passenger.)

### `Capfile`
* Remove any of the following:
```
require 'capistrano/bundler'
require 'capistrano/rails'
require 'capistrano/honeybadger'
require 'capistrano/passenger'
require 'whenever/capistrano'
require 'dlss/capistrano'
```
* Add `require 'dlss/docker/capistrano`

### `config/deploy.rb`
* For `:linked_files` remove `config/database.yml` and `config/secrets.yml` if present. Both of these will be provided by environment variables.
* For `:linked_dirs` remove `tmp/pids`, `tmp/cache`, `tmp/sockets`, `public/system` if present. `log` and `config/settings` should remain.
* Remove any sidekiq, sneakers, passenger, whenever, or shared_configs related settings.
* Add `set :docker_compose_file, 'docker-compose.prod.yml'` to reference the production docker-compose file.
* Optionally, add `set :docker_compose_seed_use_hooks, true` to perform seeding.
* Optionally, add `set :docker_compose_rabbitmq_use_hooks, true` to perform Rabbitmq setup.
* Note that there are other settings supported by this gem for additional configuration.

### `config/deploy/<environment>.rb`
* Each server should have the `app` role and any roles that correspond with profiles in the docker-compose file. This is what controls what services are run on the server.

### `config/puma.rb`
* Change `RAILS_MAX_THREAD` to `PUMA_MAX_THREAD` and `RAILS_MIN_THREAD` to `PUMA_MIN_THREAD`.
* Enable workers with `workers ENV.fetch('PUMA_WORKERS', 2)`
* Enable preload with `preload_app!`.

### `config/schedule.rb`
* Add `set :job_template, nil` to execute with sh instead of bash.

### `Dockerfile`
* When possible, base the image on Alpine (e.g., `FROM ruby:3.1-alpine`).
* Processes should run as the application user (e.g., `h2`) not root, with user id and group id set to match the server.
* If using Whenever, install Supercronic (which does not have to run as root) and write the crontab file during the build with `RUN sh -c 'bundle exec whenever . | tee -a config/crontab'`.
* When possible, write to both a log file and stdout.
* Precompile assets (`RUN bin/rails assets:precompile`) as part of the build. `SECRET_KEY_BASE` will need to be available for precompiling.

### `docker-compose.prod.yml`
* Duplicate configuration can be shared with fragments (e.g., `&environment` / `*environment`).
* The command for a container can be overridden with `command:`, e.g., `command: bin/bundle exec rake sneakers:run 2>&1 | tee -a log/sneakers.log`.
* Each service should be assigned to one or more profiles. These correspond to capistrano roles. For example:
```
profiles:
  - cron
```
* Containers should link in the shared logs directory. For example:
```
volumes:
  - /opt/app/h2/happy-heron/shared/log:/app/log
```
* Environment variables provided by the server should be passed through to the container. For example:
```
environment:
 - HONEYBADGER_API_KEY
```

### `.dockerignore`
Ignore `public.assets`
