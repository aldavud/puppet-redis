# == Class: redis::sentinel
#
# Installs redis if its not already and configures the sentinel settings.
#
# === Parameters
#
# $redis_clusters - This is a hash that defines the redis clusters
# that sentinel should watch.
#
# === Examples
#
# class { 'redis::sentinel': }
#
# redis::sentinel::redis_clusters:
#  'cluster1':
#    master_ip: '192.168.33.51'
#    quorum: 2
#    down_after: 30000
#    failover_timeout: 180000
#    parallel_syncs: 1
#  'cluster2':
#    master_ip: '192.168.33.54'
#    quorum: 4
#    down_after: 30000
#    failover_timeout: 180000
#    parallel_syncs: 5
#
# === Authors
#
# Dan Sajner <dsajner@covermymeds.com>
#
class redis::sentinel (
  $version        = 'installed',
  $redis_clusters = undef,
) {

  # Install the redis package
  ensure_packages(['redis'], { 'ensure' => $version })

  # Declare /etc/sentinel.conf here so we can manage ownership
  file { '/etc/sentinel.conf':
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    require => Package['redis'],
  }

  # Run it!
  service { 'redis-sentinel':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => Package['redis'],
  }

  # Lay down the runtime configuration script
  $config_script = '/usr/local/bin/sentinel_config.sh'

  file { $config_script:
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    mode    => '0755',
    content => template('redis/sentinel_config.sh.erb'),
    require => Package['redis'],
    notify  => Exec['configure_sentinel'],
  }

  # Apply the configuration.
  exec { 'configure_sentinel':
    command     => $config_script,
    refreshonly => true,
    require     => [ Service['redis-sentinel'], File[$config_script] ],
  }

}

