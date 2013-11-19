Exec { path => '/bin:/sbin:/usr/bin:/usr/sbin:/opt/vagrant_ruby/bin', }

node default {
  stage { 'before': before => Stage['main'], }
  class { 'repos': stage => 'before', }
  -> class { 'pdb': }
  -> class { 'pb': }
}

# Add repo for PuppetDB packages
class repos {
  include apt
  apt::source { 'puppetlabs_ubuntu':
    location => 'http://apt.puppetlabs.com/',
    release  => 'precise',
    repos    => 'main dependencies',
    key      => '4BD6EC30',
  }
}


# Class to install and configure PuppetDB
class pdb {
  # Extra resources for vagrant
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

  # Helper to import a DB after vagrant upd
  exec { 'import db':
    command => 'psql puppetdb < /vagrant/puppetdb.sql',
    onlyif  => '/usr/bin/test -f /vagrant/puppetdb.sql',
    user    => 'postgres',
    require => Class['puppetdb::database::postgresql'],
  }

  # PuppetDB configuration settings
  class { 'puppetdb::server':
    report_ttl => '0s',
  }
  class { 'puppetdb::database::postgresql': }
}


# Class to install and configure puppetboard
class pb {
  # Git for vcsrepo to clone puppetboard
  package { 'git':
    ensure => present,
  }

  # Python for running puppetboard
  class { 'python':
    pip        => true,
    virtualenv => true,
  }

  # Apache for serving puppetboard
  class { 'apache':
    mpm_module => 'prefork',
  }
  class { 'apache::mod::wsgi': }

  # Puppetboard and an apache vhost
  class { 'puppetboard':
    unresponsive => '999999',
    experimental => 'True',
  }
  class { 'puppetboard::apache::vhost':
    vhost_name => 'puppetboard.lan',
  }
}
