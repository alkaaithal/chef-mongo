
include NwMongo

default_action :run

attribute :command, String, name_property: true, required: true
attribute :database, String, required: true
attribute :cacert, String, required: true
attribute :auth_db, String
attribute :auth_user, String
attribute :auth_pass, String
attribute :host, String, default: '127.0.0.1'
attribute :port, Integer, default: 27_017

action_class do
  def connection_data
    cd = {
      host: new_resource.host,
      port: new_resource.port
    }
    cd = auth_data(cd)
    cd[:cacert] = new_resource.cacert if new_resource.cacert
    cd
  end

  # rubocop:disable Metrics/AbcSize
  def auth_data(cd)
    return cd unless node['nw-mongo']['authorization']
    cd[:auth_db] = new_resource.auth_db if new_resource.auth_db
    cd[:auth_user] = new_resource.auth_user if new_resource.auth_user
    cd[:auth_pass] = new_resource.auth_pass if new_resource.auth_pass
    cd
  end
end
# rubocop:enable Metrics/AbcSize

action :run do
  cmd = format_cli(new_resource.database, connection_data, new_resource.command)
  execute 'Executing MongoDB command' do
    command cmd
    sensitive true
    retries 2
  end
end
