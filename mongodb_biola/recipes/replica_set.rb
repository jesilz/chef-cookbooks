include_recipe 'install'

chef_gem 'mongo'

require 'mongo'

MONGODB_PORT = 27017
replica_set_name = "biola_#{node.chef_environment}"

# Find the mongo servers
db_nodes = search(:node, "role:mongodb_host AND chef_environment:#{node.chef_environment}")
arbiter_nodes = search(:node, "role:mongodb_arb AND chef_environment:#{node.chef_environment}")

# Connect to the local Mongo database
begin
  connection = Mongo::Connection.new(node.ipaddress, MONGODB_PORT, :op_timeout => 5, :slave_ok => true)
rescue
  Chef::Log.warn("Could not connect to database: #{node.ipaddress}:#{MONGODB_PORT}")
  return
end

# Build replSetInitiate command
member_id = 0
members = []
db_nodes.sort_by(&:name).each |n|
  members << { '_id' => i, 'host' => "#{n.fqdn}:#{MONGODB_PORT}" }
  i += 1
end
arbiter_nodes.sort_by(&:name).each |n|
  members << { '_id' => i, 'host' => "#{n.fqdn}:#{MONGODB_PORT}", 'arbiterOnly' => true }
  i += 1
end

# Run the replSetInitiate command
init_command = { 'replSetInitiate' => { '_id' => replica_set_name, 'members' => members } }

# Check the response
begin
  response = connection['admin'].command(init_command, :check_response => false)
rescue Mongo::OperationTimeout
  Chef::Log.info('Replica set is still being configured. Next run should be successful')
  return
end

success = result['ok'] == 1

unless success
  if result['errmsg'] == 'already initialized'

    # TODO: add and remove dbs

  else
    Chef::Log.error("Replica set initiation failed: #{result['errmsg']}")
  end
end