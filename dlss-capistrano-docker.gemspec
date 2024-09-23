# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

Gem::Specification.new do |s|
  s.name        = "dlss-capistrano-docker"
  s.version     = '1.2.0'

  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Justin Littman']
  s.email       = ['justinlittman@stanford.edu']
  s.summary     = "Capistrano recipes for use in SUL/DLSS projects for docker deployment"
  s.homepage    = 'https://github.com/sul-dlss/dlss-capistrano-docker'
  s.license     = "Apache-2.0"

  s.required_ruby_version = '>= 3.0', '< 4'

  # All dependencies are runtime dependencies, since this gem's "runtime" is
  # the dependent gem's development-time.
  s.add_dependency "capistrano", "~> 3.0"
  s.add_dependency "capistrano-bundle_audit", ">= 0.3.0"
  s.add_dependency "capistrano-one_time_key"
  s.add_dependency "capistrano-shared_configs"
  # support for MacOS 14.4+ usage of ed25519 SSH keys
  s.add_dependency "ed25519"
  s.add_dependency "bcrypt_pbkdf"

  s.add_development_dependency 'bundler'
  s.add_development_dependency 'byebug'
  s.add_development_dependency 'rake', '>= 12.3.3'
  s.add_development_dependency 'rubocop', '~> 1.0'

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.metadata['rubygems_mfa_required'] = 'true'
end
