
# Main entrypoint to create a mysql server
def mw_mysql_server(instance_name, options = {})
  mw_mysql_apply_customizations!

  mw_mysql_mount_tmp_dir if node['mw_mysql']['enable_tmpdir']

  mw_mysql_configure_apparmor instance_name

  options[:port] ||= 3306

  mysql_service instance_name do
    port options[:port]
    initial_root_password options[:root_password]
    tmp_dir node['mw_mysql']['tmpdir'] if node['mw_mysql']['enable_tmpdir']
    action [:create, :start]
  end

  mysql_tuning instance_name do
    include_dir "/etc/mysql-#{instance_name}/conf.d"
    notifies :restart, "mysql_service[#{instance_name}]"
  end

  mysql_config 'charset' do
    source 'charset.cnf.erb'
    cookbook 'mw_mysql'
    instance instance_name
    variables(charset: node['mw_mysql']['charset'],
              collation: node['mw_mysql']['collation'])
    notifies :restart, "mysql_service[#{instance_name}]"
  end

  mw_mysql_dot_file options
end

# Set server as master
def mw_mysql_master_server(options = {})
  options[:replication_password] ||= 'repl'
  options[:server_id] ||= 1
  mw_mysql_replication_server("master-#{options[:server_id]}",
                              'replication-master.erb',
                              options)
end

# Set server as slave
def mw_mysql_slave_server(options = {})
  options[:replication_password] ||= 'repl'
  options[:server_id] ||= 2
  mw_mysql_replication_server("slave-#{options[:server_id]}",
                              'replication-slave.erb',
                              options)
  mw_replication_start_slave! options
end

# Configures replication for mysql
def mw_mysql_replication_server(instance_name, template, options)
  mw_mysql_server instance_name, options

  node.set['mw_mysql']['instances']||= {}
  node.set['mw_mysql']['instances'][instance_name]['log_dir'] = "/var/log/mysql-#{instance_name}"

  mysql_config "Replication #{instance_name}" do
    config_name 'replication'
    instance instance_name
    source template
    cookbook 'mw_mysql'
    variables(server_id: options[:server_id], mysql_instance: instance_name, logs: node['mw_mysql']['instances'][instance_name]['log_dir'])
    notifies :restart, "mysql_service[#{instance_name}]", :immediately
    action :create
  end

  mw_replication_create_user options
end

def mw_mysql_configure_apparmor(instance_name)
  # Do not add these resource if inside a container
  # Only valid on Ubuntu
  return if ::File.exist?('/.dockerenv') && ::File.exist?('/.dockerinit')

  include_recipe 'chef-sugar'
  require 'chef/sugar'

  # Return if not ubuntu
  return unless Chef::Sugar::Platform.ubuntu?(node)

  service 'apparmor' do
    service_name 'apparmor'
    action :nothing
  end

  directory instance_name do
    path '/etc/apparmor.d/local/mysql'
    owner 'root'
    group 'root'
    mode '0755'
    recursive true
    action :create
  end

  file 'apparmor tmpfs mysql' do
    path "/etc/apparmor.d/local/mysql/#{instance_name}-tmpfs"
    owner 'root'
    group 'root'
    mode '0644'
    content <<-EOT
    #{node['mw_mysql']['tmpdir']}/ r,
    #{node['mw_mysql']['tmpdir']}/** rwk,
    EOT
    notifies :restart, 'service[apparmor]', :immediately
  end
end

def mw_mysql_config_filename(options)
  options[:config_file] || '/root/.my.cnf'
end

# Creates root user mysql config so it will not ask password to login as root
def mw_mysql_dot_file(options)
  password = options[:root_password]
  port = options[:port]
  config_file_name = mw_mysql_config_filename(options)
  file config_file_name do
    sensitive true
    content <<-MYCNF
[client]
  password=#{password}
  host=127.0.0.1
  port=#{port}
  user=root
  MYCNF
    mode '0600'
  end
end

# Apply some tuning customizations
def mw_mysql_apply_customizations!
  node.set['mysql_tuning']['tuning.cnf']['mysqld']['innodb_log_files_in_group'] = 2
  node.set['mysql_tuning']['tuning.cnf']['mysqld']['max_connections'] =
    node['mw_mysql']['max_connections'] if node['mw_mysql']['max_connections']
  node.set['mysql_tuning']['logging.cnf']['mysqld']['expire_logs_days'] =
    node['mw_mysql']['expire_logs_days'] if node['mw_mysql']['expire_logs_days']
end

# Creates replication user
def mw_replication_create_user(options)
  replication_password = options[:replication_password]
  bash 'create replication user' do
    code <<-EOF
    /usr/bin/mysql --defaults-file=#{mw_mysql_config_filename(options)} -D mysql \
      -e "CREATE USER 'repl'@'%' IDENTIFIED BY '#{Shellwords.escape(replication_password)}';"
    /usr/bin/mysql --defaults-file=#{mw_mysql_config_filename(options)} -D mysql \
      -e "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';"
    EOF
    not_if "/usr/bin/mysql --defaults-file=#{mw_mysql_config_filename(options)} -e 'select User,Host from mysql.user' | grep repl"
    action :run
  end
end

# Start slave instance
def mw_replication_start_slave!(options)
  master_host = options[:master_host]
  master_port = options[:master_port]
  config_file_name = mw_mysql_config_filename(options)
  Chef::Application.fatal! 'Master host must be specified when configuring slave: nil received as master host' unless master_host
  replication_password = options[:replication_password]
  ruby_block 'start_slave' do
    block do
      query = ' CHANGE MASTER TO'
      query << " MASTER_HOST='#{master_host}',"
      query << " MASTER_PORT=#{master_port}," if master_port
      query << " MASTER_USER='repl',"
      query << " MASTER_PASSWORD='#{Shellwords.escape(replication_password)}';"
      query << ' START SLAVE;'
      shell_out!("echo \"#{query}\" | /usr/bin/mysql --defaults-file=#{config_file_name}")
    end
    not_if "/usr/bin/mysql --defaults-file=#{config_file_name} -Ee 'SHOW SLAVE STATUS' | grep Slave_IO_State"
    action :run
  end
end

# Mount mysql tmpdir
def mw_mysql_mount_tmp_dir
  directory node['mw_mysql']['tmpdir']

  mount node['mw_mysql']['tmpdir'] do
    pass 0
    fstype 'tmpfs'
    device 'tmpfs'
    options "rw,mode=1777,nr_inodes=10k,size=#{node['mw_mysql']['tmpdir_size']}"
    action [:mount, :enable]
  end
end
