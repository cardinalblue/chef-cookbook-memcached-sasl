#
# Cookbook:: memcached-sasl
# Recipe:: default
#
# Copyright:: 2017, The Authors, All Rights Reserved.

sasl_pkgs = []

case node['platform_family']
  when 'debian'
    sasl_pkgs = %w(libsasl2-2 libsasl2-modules sasl2-bin)
  when 'rhel'
    sasl_pkgs = if node['platform_version'].to_i < 6
                  %w(cyrus-sasl cyrus-sasl-plain openssl)
                else
                  %w(cyrus-sasl cyrus-sasl-plain ca-certificates)
                end
  when 'fedora'
    sasl_pkgs = %w(cyrus-sasl cyrus-sasl-plain ca-certificates)
end

sasl_pkgs.each do |pkg|
  package pkg
end

template '/usr/lib/sasl2/memcached.conf' do
  source 'memcached_sasl.conf.erb'
  owner 'root'
  group 'root'
  mode '400'
end

execute 'saslpasswd2' do
  user 'root'
  sensitive true
  command "echo #{node['memcached']['sasl_user_password']} | saslpasswd2 -p -c -a memcached #{node['memcached']['sasl_user_name']}"
end

package 'memcached' do
  action :upgrade
end

directory '/etc/systemd/system/memcached.service.d/' do
  owner 'root'
  group 'root'
  mode '0755'
  recursive true
  action :create
end

execute 'daemon-reload' do
  command 'systemctl daemon-reload'
  user 'root'
  action :nothing
end

service 'memcached' do
  action [:start, :enable]
  supports :status => true, :start => true, :stop => true, :restart => true
end

template '/lib/systemd/system/memcached.service' do
  source 'memcached.service.erb'
  variables(
    port: node['memcached']['port'],
    memory: node['memcached']['memory']
  )
  owner 'root'
  group 'root'
  mode '0644'
  notifies :restart, 'service[memcached]', :delayed
  notifies :run, 'execute[daemon-reload]', :immediately
end
