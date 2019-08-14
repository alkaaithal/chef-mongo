admin = node['mongodb']['admin']

default_roles = [
  {
    'role' => 'userAdminAnyDatabase',
    'db' => 'admin'
  }
]


#users.concat(node['mongodb']['users'])
# Add each user specified in attributes
node['mongodb']['users'].each do |user|
  starter_user user['username'] do
    sensitive true
    p user['username']
    password user['password']
    roles default_roles
    p user['roles']
    database user['database']
    p database
    connection node['mongodb']
    action :add
  end
end
