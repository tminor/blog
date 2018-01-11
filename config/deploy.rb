set :application, "Blog"
set :repository, '_site'
set :scm, :none
set :deploy_via, :copy
set :copy_compression, :gzip
set :use_sudo, false

set :copy_local_tar, "/usr/local/bin/gtar" if `uname` =~ /Darwin/

# the name of the user that should be used for deployments on your VPS
set :user, "tminor"

# the path to deploy to on your VPS
set :deploy_to, "/var/www/blog.tminor.io/"

ssh_options[:keys] = [
    File.join(ENV["HOME"], ".ssh", "DigitalOcean")
    ]

ssh_options[:forward_agent] = true

# the ip address of your VPS
role :web, "104.236.52.182"

before 'deploy:update', 'deploy:update_jekyll'

namespace :deploy do
  [:start, :stop, :restart, :finalize_update].each do |t|
    desc "#{t} task is a no-op with jekyll"
    task t, :roles => :app do ; end
  end

  desc 'Run jekyll to update site before uploading'
  task :update_jekyll do
    # clear existing _site
    # build site using jekyll
    # remove Capistrano stuff from build
    %x(rm -rf _site/* && bundle exec jekyll build && rm _site/Capfile && rm -rf _site/config)
  end
end