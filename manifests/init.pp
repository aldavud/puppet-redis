# == Class: redis
#
# Installs and configures redis.
#
# === Parameters
#
# $config: A hash of Redis config options to apply at runtime
# $manage_persistence: Boolean flag for including the redis::persist class
#
# === Examples
#
# $config_hash = {
#   'dir'       => '/pub/redis',
#   'maxmemory' => '1073741824' }
#
# class { redis:
#   config  => $config_hash,
#   slaveof => '192.168.33.10',
# }
#
# === Authors
#
# Dan Sajner <dsajner@covermymeds.com>
#
class redis (
  $config             = {},
  $slaveof            = undef,
  $manage_persistence = false,
  $version            = 'installed',
) {

  # Install the redis package
  ensure_packages(['redis'], { 'ensure' => $version })

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
