require 'json'

# Helper methods for the nw-mongo cookbook.
module NwMongo
  # Abstraction of simple call-outs to obtain MongoDB information.
  #
  # @param database [String] name of the target mongo database
  # @param connection [Hash] connection parameters
  # @option connection [String] :auth_db authentication database
  # @option connection [String] :auth_user authentication username
  # @option connection [String] :auth_pass authentication password
  # @option connection [String] :host MongoDB hostname/IP
  # @option connection [String] :port MongoDB listening port
  # @option connection [String] :cacert TLS CA certificate path
  # @param cmd [String] Command to be executed
  # @param retries [Integer] Number of times to attempt command (default none)
  # @return [String] output from mongo shell
  def run_cmd(database, connection, cmd, retries = 0)
    current = 0
    cli = format_cli(database, connection, cmd)
    while current <= retries
      mixlib = Mixlib::ShellOut.new(cli)
      mixlib.run_command
      break unless mixlib.error?
      current += 1
      Kernel.sleep(2)
    end
    mixlib.stdout
  end

  # Returns a fully structured mongo shell command syntax.
  #
  # @param database [String] MongoDB database name
  # @param connection [Hash] connection parameters
  # @option connection [String] :auth_db authentication database
  # @option connection [String] :auth_user authentication username
  # @option connection [String] :auth_pass authentication password
  # @option connection [String] :host MongoDB hostname/IP
  # @option connection [String] :port MongoDB listening port
  # @option connection [String] :cacert TLS CA certificate path
  # @param content [String..] one or more mongo commands
  # @return [String] mongo shell invocation syntax
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

  private

  def _tls(connection, syntax)
    return unless connection.key?(:cacert) && connection[:cacert]
    fmt = "mongo --quiet --host '%s' --port '%s' " \
          "--ssl --sslAllowInvalidHostnames --sslCAFile '%s' " \
          "--eval '%s'"
    # NOTE: single quotes in eval command require special handling; for each
    # single quote that appears in the command, break command into multiple
    # single-quote wrapped segments while wrapping the original single quote
    # in double quotes.
    format(
      fmt, connection[:host], connection[:port],
      connection[:cacert], syntax.gsub(/'/, "'\"'\"'")
    )
  end

  def _notls(connection, syntax)
    return if connection.key?(:cacert) && connection[:cacert]
    fmt = "mongo --quiet --host '%s' --port '%s' " \
          "--eval '%s'"
    # NOTE: single quotes in eval command require special handling; for each
    # single quote that appears in the command, break command into multiple
    # single-quote wrapped segments while wrapping the original single quote
    # in double quotes.
    format(fmt, connection[:host],
           connection[:port], syntax.gsub(/'/, "'\"'\"'"))
  end

  # Adds authentication to the mongo shell invocation.
  #
  # @param auth [Hash] options
  # @option auth [String] :auth_db
  # @option auth [String] :auth_user
  # @option auth [String] :auth_pass
  # @return [Array<String>] commands
  def _add_auth(auth)
    return [] if auth.keys.empty? || auth[:auth_db].nil?
    db = auth[:auth_db]
    user = auth[:auth_user]
    pass = auth[:auth_pass]
    [%(db.getSiblingDB("#{db}").auth("#{user}", "#{pass.gsub(/"/, '\"')}"))]
  end
end
