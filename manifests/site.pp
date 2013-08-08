Exec { path => '/bin:/sbin:/usr/bin:/usr/sbin:/opt/vagrant_ruby/bin', }

node default {
  stage { 'before': before => Stage['main'], }
  class { 'repos': stage => 'before', }
  -> class { 'pdb': }
  -> class { 'puppetboard': }
}

class repos {
  include apt
  apt::source { 'puppetlabs_ubuntu':
    location => 'http://apt.puppetlabs.com/',
    release  => 'precise',
    repos    => 'main dependencies',
    key      => '4BD6EC30',
  }
}

class pdb {
  host { $::fqdn:
    ip           => '127.0.0.1',
    host_aliases => $::hostname,
    before       => Exec['create cert'],
  }
  exec { 'create cert':
    command => "puppet cert generate ${::fqdn} --dns_alt_names puppet",
    unless  => "puppet cert list ${::fqdn}",
    before  => [
      Class['puppetdb::server'],
      Class['puppetdb::database::postgresql']
    ]
  }
  class { 'puppetdb::server': }
  class { 'puppetdb::database::postgresql': }
  ini_setting { 'report-ttl':
    ensure  => present,
    path    => '/etc/puppetdb/conf.d/database.ini',
    setting => 'report-ttl',
    value   => '0s',
    section => 'database',
    require => Package['puppetdb'],
    notify  => Service['puppetdb'],
  }
}

class puppetboard {
  package { ['git','python-pip','dtach']:
    ensure => present,
  }
  package { ['pytz','requests']:
    ensure   => present,
    provider => 'pip',
    before   => Exec['install puppetboard'],
  }
  vcsrepo { "/root/puppetboard":
    ensure   => present,
    provider => 'git',
    source   => 'https://github.com/nedap/puppetboard',
    before   => Exec['install puppetboard'],
  }
  exec { 'install puppetboard':
    command => 'pip install -r /root/puppetboard/requirements.txt',
    unless  => 'pip freeze|grep Flask',
  }
  file_line { 'puppetboard listen':
    path    => '/root/puppetboard/dev.py',
    line    => "    app.run('0.0.0.0')",
    match   => '    app.run\(\'([\d\.]+)\'\)',
    notify  => Service['puppetboard'],
    require => Exec['install puppetboard'],
  }
  file_line { 'puppetboard experimental':
    path    => '/root/puppetboard/puppetboard/default_settings.py',
    line    => 'PUPPETDB_EXPERIMENTAL=True',
    match   => 'PUPPETDB_EXPERIMENTAL=(True|False)',
    notify  => Service['puppetboard'],
    require => Exec['install puppetboard'],
  }
  service { 'puppetboard':
    ensure     => running,
    start      => 'dtach -n /root/puppetboard/dtach python /root/puppetboard/dev.py',
    stop       => 'pkill python',
    provider   => 'base',
    hasstatus  => false,
    hasrestart => false,
    require    => Package['dtach'],
  }
}
