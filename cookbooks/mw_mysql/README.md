# Personalized mysql server cookbook

[![Build Status](https://travis-ci.org/Mikroways/mw_mysql.svg?branch=master)](https://travis-ci.org/Mikroways/mw_mysql) [![Cookbook Version](https://img.shields.io/cookbook/v/mw_mysql.svg)](https://supermarket.chef.io/cookbooks/mw_mysql)

The `mw_mysql` cookbook provides recipes for installing mysql server as a
standalone instance, or acting as master or slave instance. Another feature
provided is the fact that integrates with `mysql_tuning` cookbook.

Requirements
------------

* Chef 12+

Platform support
----------------

The following platforms have been tested with test kitchen

* Debian 7.8
* Debian 8.2
* Ubuntu 14.04
* Centos 6.7
* Centos 7.2

Cookbook dependencies
---------------------

* mysql
* mysql_tuning
* chef-sugar

Other cookbooks may be required depending on the platform used:

* apt/yum so packages are updated if ubuntu/debian/centos/rhel

Usage
-----

Place a dependency on the mw_application cookbook in your cookbook's metadata.rb

```ruby
  depends 'mw_mysql', '~> 0.1.0'
```

Then, in a recipe you can use provided recipes or helper functions

Attributes
----------

* `default['mw_mysql']['enable_tmpdir']`: enable tmpdir for mysql temporay dir.
  It will mount a ram disk to speed up mysql file operations. It will not
enabled by default
* `default['mw_mysql']['tmpdir']`: directory to mount temporary RAM disk
* `default['mw_mysql']['tmpdir_size']`: RAM disk size
* `default['mw_mysql']['charset']`: default server charset
* `default['mw_mysql']['collation']`: default server collation.
* `default['mw_mysql']['max_connections']`: number of max connections allows. If
  nil, it will be calculated by mysql_tuning cookbook based on hardware specs
* `default['mw_mysql']['expire_logs_days']`: number of binary logs to be kept


Recipes
-------

Recipes provided are only provided as examples so, not use them in prduction.
Mysql server installed will used default password


### `mw_mysql::client`

Installs mysql client command line

### `mw_mysql::default`

Installs a mysql server with root password set as `change me`


Helpers
-------

### `mw_mysql_server`

This helper receives two arguments:

* Mysql instance name
* Hash with options where:
  * root_password: is the root password
  * port: specifies mysql instance tcp port. Defaults to 3306

#### Example usage

```ruby
mw_mysql_server('main', root_password: 'some_password', port: 3307)
mw_mysql_server('other', root_password: 'some_password', port: 3308)
```

Will install two mysql instances: one named **main** which listens on port
**3307** and **other** which listens on port **3308**

### `mw_mysql_master_server`

This helper receives only a hash with options, where the same options specified
for `mw_mysql_server` helper are supported, but other ones are available:

* `replication_password`: password used for the replication user
* `server_id`: id of the mysql instance

#### Example usage

```ruby
mw_mysql_master_server root_password: 'master',
                       port: 3306,
                       replication_password: 'replication'
```

### `mw_mysql_slave_server`

This helper receives only a hash with options, where the same options specified
for `mw_mysql_server` helper are supported, but other ones are available:

* `replication_password`: password used for the replication user
* `server_id`: id of the mysql instance
* `master_host`: ip address of mysql master server. **Required**
* `master_port`: port of mysql master server

#### Example usage

```ruby
mw_mysql_slave_server root_password: 'slave',
                      port: 3307,
                      replication_password: 'replication',
                      master_host: '127.0.0.1'
```

## Kitchen testing

Travis will use default .kitchen based on Docker driver. 

If you prefer to test recipe for all platforms, run:

```
KITCHEN_LOCAL_YAML=.kitchen_vagrant.yml
```

