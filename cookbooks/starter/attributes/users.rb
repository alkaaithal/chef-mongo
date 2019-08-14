default['mongodb']['admin'] = {
  'username' => 'myUserAdmin',
  'password' => 'abc123',
  'roles' => %w(userAdminAnyDatabase dbAdminAnyDatabase),
  'database' => 'admin'
}

default['mongodb']['users'] = []
