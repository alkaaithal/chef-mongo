attribute :username, :kind_of => String, :name_attribute => true
attribute :password, :kind_of => String
attribute :roles, :kind_of => Array
attribute :database, :kind_of => String
attribute :connection, :kind_of => Hash
attribute :host, String, default: '127.0.0.1'
attribute :port, Integer, default: 27_017
attribute :auth_user, String
attribute :auth_pass, String

require 'json'

default_action :add

action_class do
  def connection
    cd = {
      host: new_resource.host,
      port: new_resource.port
    }
end

action :add do
  execute "Creating MongoDB user #{new_resource.username}" do
    command create_user(
      new_resource.username, new_resource.password, new_resource.database, new_resource.roles, connection
    )
  end
end



def create_user(user, passwd, database, roles, connection = {})
  data = { user: user, roles: roles }
  data[:pwd] = passwd unless passwd.nil? || passwd.empty?

  args = JSON.generate(data)
  format_cli(database, connection, format('db.createUser(%s)', args))
end




def format_cli(database, connection, *content)
  content = [content] unless content.respond_to?(:each)
  syntax = []
  syntax.concat(_add_auth(connection))
  syntax << %(db = db.getSiblingDB("#{database}"))
  syntax.concat(content)
  syntax = syntax.join("\n")
  if connection.key?(:cacert) && connection[:cacert]
    return _tls(connection, syntax)
  end
  _notls(connection, syntax)
end


def _tls(connection, syntax)
  return unless connection.key?(:cacert) && connection[:cacert]
  fmt = "mongo --quiet --host '%s' --port '%s' " \
        "--ssl --sslAllowInvalidHostnames --sslCAFile '%s' " \
        "--eval '%s'"
  format(
    fmt, connection[:host], connection[:port],
    connection[:cacert], syntax.gsub(/'/, "'\"'\"'")
  )
end

def _notls(connection, syntax)
  return if connection.key?(:cacert) && connection[:cacert]
  fmt = "mongo --quiet --host '%s' --port '%s' " \
        "--eval '%s'"
  format(fmt, connection[:host],
         connection[:port], syntax.gsub(/'/, "'\"'\"'"))
end

def _add_auth(auth)
  return [] if auth.keys.empty? || auth[:auth_db].nil?
  db = auth[:auth_db]
  user = auth[:auth_user]
  pass = auth[:auth_pass]
  [%(db.getSiblingDB("#{db}").auth("#{user}", "#{pass.gsub(/"/, '\"')}"))]
end
end
