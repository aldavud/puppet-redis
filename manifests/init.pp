# == Class: redis
#
# Installs and configures redis.
#
# === Parameters
#
# $config: A hash of Redis config options to apply at runtime
# $bind: IP addresses to bind to
# $slaveof: IP address of the initial master Redis server
# $manage_persistence: Boolean flag for including the redis::persist class
# $version: The package version of Redis you want to install
#
# === Examples
#
# $config_hash = {
#   'dir'       => '/pub/redis',
#   'maxmemory' => '1073741824' }
#
# class { redis:
#   config  => $config_hash,
#   bind    => '10.0.0.2 127.0.0.1'
#   slaveof => '10.0.0.1',
# }
#
# === Authors
#
# Dan Sajner <dsajner@covermymeds.com>
#
class redis (
  $config             = {},
  $bind               = '127.0.0.1',
  $slaveof            = undef,
  $manage_persistence = false,
  $version            = 'installed',
) {

  # Install the redis package
  ensure_packages(['redis'], { 'ensure' => $version })

  # Lay down intermediate config file and copy it in with a 'cp' exec resource.
  # Redis rewrites its config file with additional state information so we only
  # want to do this the first time redis starts so we can at least get it 
  # daemonized and assign a master node if applicable.
  file { '/etc/redis.conf.puppet':
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    mode    => '0644',
    content => template('redis/redis.conf.erb'),
    require => Package['redis'],
    notify  => Exec['cp_redis_config'],
  }

  exec { 'cp_redis_config':
    command     => '/bin/cp -p /etc/redis.conf.puppet /etc/redis.conf',
    refreshonly => true,
    notify      => Service[redis],
  }

  # Declare /etc/redis.conf so that we can manage the ownership
  file { '/etc/redis.conf':
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    require => Package['redis'],
  }

  # Run it!
  service { 'redis':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => Package['redis'],
  }

  # Lay down the configuration script, content based on the config hash.
  $config_script = '/usr/local/bin/redis_config.sh'

  file { $config_script:
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    mode    => '0755',
    content => template('redis/redis_config.sh.erb'),
    require => Package['redis'],
    notify  => Exec['configure_redis'],
  }

  # Apply the configuration.
  exec { 'configure_redis':
    command     => $config_script,
    refreshonly => true,
    require     => [ Service['redis'], File[$config_script] ],
  }

  # In an HA setup we choose to only persist data to disk on
  # the slaves for better performance.
  include redis::persist

}
