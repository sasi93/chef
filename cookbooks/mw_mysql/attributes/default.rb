default['mw_mysql']['enable_tmpdir'] = false
default['mw_mysql']['tmpdir'] = '/var/mysqltmp'
default['mw_mysql']['tmpdir_size'] = '2G'

default['mw_mysql']['charset'] = 'utf8'
default['mw_mysql']['collation'] = 'utf8_general_ci'

# If not defined, they will be automatically calculated by mysql_tunning
# cookbook
default['mw_mysql']['max_connections'] = nil
default['mw_mysql']['expire_logs_days'] = nil
