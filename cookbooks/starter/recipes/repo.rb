yum_repository 'mongodb' do
    description 'MongoDB Repository'
    node['repo']['mongo'].each do |repo|
    baseurl repo['baseurl']
    gpgkey repo['gpgkey']
    action :create
    end
end
