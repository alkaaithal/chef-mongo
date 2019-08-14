execute 'daemon_reload' do
    command 'systemctl --system daemon-reload'
    action :nothing
end

service 'mongod' do
    action [:enable, :start]
end
