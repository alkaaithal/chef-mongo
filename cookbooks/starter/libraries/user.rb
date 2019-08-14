require 'json'

module NwMongo
  # Methods to support managing users in MongoDB.
  module User
    include NwMongo

    # Returns true if the specified MongoDB user exists in the specified
    # database.
    #
    # @param user [String] MongoDB username
    # @param database [String] MongoDB database name
    # @param connection [Hash] connection parameters
    # @option connection [String] :auth_db authentication database
    # @option connection [String] :auth_user authentication username
    # @option connection [String] :auth_pass authentication password
    # @option connection [String] :host MongoDB hostname/IP
    # @option connection [String] :port MongoDB listening port
    # @option connection [String] :cacert TLS CA certificate path
    # @return [Boolean] whether the user exists
    def user_exists?(user, database, connection = {})
      Chef::Log.info("Checking for MongoDB user #{user} in db #{database}")
      out = run_cmd(database, connection, %(db.getUser("#{user}")), 2)
      log_regex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[-+]\d{4} \w/
      user_regex =
        /"_id" : "#{Regexp.escape(database)}.#{Regexp.escape(user)}",/
      filtered = out.each_line.reject do |x|
        x.match(log_regex)
      end.join($INPUT_RECORD_SEPARATOR)
      return true if filtered =~ user_regex
      false
    end

    # Adds a user to the Mongo database.
    #
    # @param user [String] MongoDB username
    # @param passwd [String] MongoDB password
    # @param database [String] MongoDB database name
    # @param roles [Array<Hash>] list of roles to be assigned
    # @param connection [Hash] connection parameters
    # @option connection [String] :auth_db authentication database
    # @option connection [String] :auth_user authentication username
    # @option connection [String] :auth_pass authentication password
    # @option connection [String] :host MongoDB hostname/IP
    # @option connection [String] :port MongoDB listening port
    # @option connection [String] :cacert TLS CA certificate path
    # @return [String] the method with args
    def create_user(user, passwd, database, roles, connection = {})
      data = { user: user, roles: roles }
      data[:pwd] = passwd unless passwd.nil? || passwd.empty?

      args = JSON.generate(data)
      format_cli(database, connection, format('db.createUser(%s)', args))
    end

    # Update a user in the Mongo database.
    #
    # Mongo throws an error if the user does not exist.
    #
    # @param user [String] MongoDB username
    # @param passwd [String] MongoDB password
    # @param database [String] MongoDB database name
    # @param roles [Array<Hash>] list of roles to be assigned
    # @param connection [Hash] connection parameters
    # @option connection [String] :auth_db authentication database
    # @option connection [String] :auth_user authentication username
    # @option connection [String] :auth_pass authentication password
    # @option connection [String] :host MongoDB hostname/IP
    # @option connection [String] :port MongoDB listening port
    # @option connection [String] :cacert TLS CA certificate path
    # @return [String] the method with args
    def update_user(user, passwd, database, roles, connection = {})
      data = { roles: roles }
      data[:pwd] = passwd unless passwd.nil? || passwd.empty?

      args = JSON.generate(data)
      format_cli(database, connection,
                 format('db.updateUser("%s",%s)', user, args))
    end

    # Removes a user from the Mongo database.
    #
    # @param user [String] MongoDB username
    # @param database [String] MongoDB database name
    # @param connection [Hash] connection parameters
    # @option connection [String] :auth_db authentication database
    # @option connection [String] :auth_user authentication username
    # @option connection [String] :auth_pass authentication password
    # @option connection [String] :host MongoDB hostname/IP
    # @option connection [String] :port MongoDB listening port
    # @option connection [String] :cacert TLS CA certificate path
    # @return [String] the method with args
    def delete_user(user, database, connection)
      format_cli(database, connection, format(%(db.dropUser("%s")), user))
    end

    # Executes the necessary mongo shell commands to add and/or remove
    # roles from a MongoDB user.
    #
    # @param user [String] MongoDB username
    # @param database [String] MongoDB database name
    # @param roles [Array] List of roles the user should possess
    # @param connection [Hash] connection parameters
    # @option connection [String] :auth_db authentication database
    # @option connection [String] :auth_user authentication username
    # @option connection [String] :auth_pass authentication password
    # @option connection [String] :host MongoDB hostname/IP
    # @option connection [String] :port MongoDB listening port
    # @option connection [String] :cacert TLS CA certificate path
    # @return [String] mongo shell command(s)
    def update_roles(user, database, new_roles, connection)
      existing_roles = _user_roles(user, database, connection)
      add = (new_roles - existing_roles)
      del = (existing_roles - new_roles)
      format_cli(
        database,
        connection,
        _grant_role(user, add),
        _revoke_role(user, del)
      )
    end

    # Performs an order-independent comparison of the specified MongoDB
    # user's currently assigned roles versus the supplied list of roles.
    # All hash keys are converted to symbols for consistency during the
    # compare.
    #
    # The existing list is returned if differences are detected, and the
    # supplied list is returned otherwise.
    #
    # This method is intended to be used to support idempotency in the
    # `nw_mongo_user` LWRP, as both the order of the contents of the
    # user's assigned roles and the supplied role list are not guaranteed,
    # and order matters during `==` comparison.
    #
    # @param user [String] MongoDB username
    # @param database [String] MongoDB database name
    # @param new_roles [Array<Hash>] List of roles
    # @param connection [Hash] connection parameters
    # @option connection [String] :auth_db authentication database
    # @option connection [String] :auth_user authentication username
    # @option connection [String] :auth_pass authentication password
    # @option connection [String] :host MongoDB hostname/IP
    # @option connection [String] :port MongoDB listening port
    # @option connection [String] :cacert TLS CA certificate path
    # @return [Array<Hash>] List of roles
    def compare_roles(user, database, new_roles, connection)
      existing_roles = _user_roles(user, database, connection)
      new_roles.map! { |r| Hash[r.map { |k, v| [k.to_sym, v] }] }
      new_roles.sort! { |a, b| a[:role] <=> b[:role] }
      existing_roles.sort! { |a, b| a[:role] <=> b[:role] }

      return new_roles if new_roles == existing_roles
      existing_roles
    end

    private

    # Retrieves the list of assigned roles for a given MongoDB user. All
    # hash keys are converted to symbols for consistency.
    #
    # @param user [String] MongoDB username
    # @param database [String] MongoDB database name
    # @param connection [Hash] connection parameters
    # @option connection [String] :auth_db authentication database
    # @option connection [String] :auth_user authentication username
    # @option connection [String] :auth_pass authentication password
    # @option connection [String] :host MongoDB hostname/IP
    # @option connection [String] :port MongoDB listening port
    # @option connection [String] :cacert TLS CA certificate path
    # @return [Array] List of assigned roles
    def _user_roles(user, database, connection)
      out = run_cmd(database, connection, %(db.getUser("#{user}")), 2)
      begin
        json = JSON.parse(out)
        json['roles'].map { |r| Hash[r.map { |k, v| [k.to_sym, v] }] }
      rescue
        []
      end
    end

    def _grant_role(user, add)
      return if add.empty?
      format('db.grantRolesToUser("%s", %s)', user, JSON.generate(add))
    end

    def _revoke_role(user, del)
      return if del.empty?
      format('db.revokeRolesFromUser("%s", %s)', user, JSON.generate(del))
    end
  end
end
