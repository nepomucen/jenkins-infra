# Run containerized Confluence to serve wiki.jenkins-ci.org
# see https://github.com/jenkins-infra/confluence for how the container is put together
#
# this class puts apache virtual host for wiki.jenkins-ci.org, which forwards requests to
#
class profile::confluence (
  $image_tag,         # tag of confluence container
  $cache_image_tag,   # tag of confluence cache container
) {
  # as a preparation, deploying mock-webapp and not the real confluence

  include profile::docker
  include profile::apache-misc

  file { '/var/log/apache2/wiki.jenkins-ci.org':
    ensure => directory,
  }
  file { '/srv/wiki':
    ensure  => directory,
    recurse => true,
  }
  file { '/srv/wiki/home':
    ensure  => directory,
    recurse => true,
  }
  file { '/srv/wiki/docroot':
    ensure  => directory,
    recurse => true,
  }

  docker::image { 'jenkinsciinfra/mock-webapp':
    image_tag => $image_tag,
  }

  docker::run { 'confluence':
    command         => undef,
    ports           => ['127.0.0.1:8081:8080'],
    image           => "jenkinsciinfra/mock-webapp:${image_tag}",
    volumes         => ['/srv/wiki/home:/srv/wiki/home', '/srv/wiki/cache:/srv/wiki/cache'],
    env             => ['APP="Jenkins Wiki"'],
    restart_service => true,
    use_name        => true,
  }

  docker::image { 'jenkinsciinfra/confluence-cache':
    image_tag => $cache_image_tag,
  }

  docker::run { 'confluence-cache':
    command         => undef,
    ports           => ['127.0.0.1:8009:8080'],
    image           => "jenkinsciinfra/confluence-cache:${cache_image_tag}",
    volumes         => ['/srv/wiki/cache:/cache'],
    links           => ['confluence:backend'],
    env             => ['TARGET=http://backend:8080'],
    restart_service => true,
    use_name        => true,
  }

  apache::mod { 'proxy':
  }

  apache::mod { 'proxy_http':
  }

  apache::vhost { 'wiki.jenkins-ci.org':
    vhost_name      => 'wiki.jenkins-ci.org',
    port            => '443',
    ssl             => true,
    docroot         => '/srv/wiki/docroot',
    access_log      => false,
    error_log_file  => 'wiki.jenkins-ci.org/error.log',
    log_level       => 'warn',
    custom_fragment => template("${module_name}/confluence/vhost.conf"),

    notify          => Service['apache2'],
    require         => File['/var/log/apache2/wiki.jenkins-ci.org'],
  }
  apache::vhost { 'wiki.jenkins-ci.org non-ssl':
    # redirect non-SSL to SSL
    servername      => 'wiki.jenkins-ci.org',
    vhost_name      => 'wiki.jenkins-ci.org',
    port            => '80',
    docroot         => '/srv/wiki/docroot',
    redirect_status => 'temp',
    redirect_dest   => 'https://wiki.jenkins-ci.org/'
  }

  host { 'wiki.jenkins-ci.org':
    ip => '127.0.0.1',
  }
}
