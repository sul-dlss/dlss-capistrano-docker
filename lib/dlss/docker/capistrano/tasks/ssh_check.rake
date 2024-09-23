# frozen_string_literal: true

desc 'check ssh connections to all app servers'
task :ssh_check do
  on roles(:app), in: :sequence do |host|
    exec "ssh -l #{host.user} #{host.hostname} -p #{host.port || 22} -t 'env'"
  end
end
