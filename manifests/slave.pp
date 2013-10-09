# Class: jenkins::slave
#
#  FYI: this module needs testing on OS's other than RHEL/Centos.  
#
#  ensure is not immplemented, since I'm
#  assuming you want to actually install the slave
#  by declaring it..
#
# enable is being added to allow you to not autostart the the slave, if necessary.
#
#
class jenkins::slave (
  $masterurl = undef,
  $ui_user = undef,
  $ui_pass = undef,
  $version = $jenkins::params::swarm_version,
  $executors = 2,
  $manage_slave_user = true,
  $slave_user = 'jenkins-slave',
  $slave_uid = undef,
  $slave_home = '/home/jenkins-slave',
  $labels = undef,
  $install_java       = $jenkins::params::install_java,
  $enable = true
) inherits jenkins::params {

  $client_jar = "swarm-client-${version}-jar-with-dependencies.jar"
  $client_url = "http://maven.jenkins-ci.org/content/repositories/releases/org/jenkins-ci/plugins/swarm-client/${version}/"

  if $install_java {
    class {java:
      distribution => 'jdk'
    }
  }

  #add jenkins slave user if necessary.

  if $manage_slave_user and $slave_uid {
    user { 'jenkins-slave_user':
      ensure     => present,
      name       => $slave_user,
      comment    => 'Jenkins Slave user',
      home       => $slave_home,
      managehome => true,
      uid        => $slave_uid
    }
  }

  if ($manage_slave_user) and (! $slave_uid) {
    user { 'jenkins-slave_user':
      ensure     => present,
      name       => $slave_user,
      comment    => 'Jenkins Slave user',
      home       => $slave_home,
      managehome => true,
    }
  }

  exec { 'get_swarm_client':
    command      => "wget -O ${slave_home}/${client_jar} ${client_url}/${client_jar}",
    path         => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    user         => $slave_user,
    #refreshonly => true,
    creates      => "${slave_home}/${client_jar}"
    ## needs to be fixed if you create another version..
  }

  if $ui_user {
    $ui_user_flag = "-username ${ui_user}"
  }
  else {$ui_user_flag = ''}

  if $ui_pass {
    $ui_pass_flag = "-password ${ui_pass}"
  } else {
    $ui_pass_flag = ''
  }

  if $masterurl {
    $masterurl_flag = "-master ${masterurl}"
  } else {
    $masterurl_flag = ''
  }

  if $labels {
    $labels_flag = "-labels \"${labels}\""
  } else {
    $labels_flag = ''
  }

  file { '/etc/init.d/jenkins-slave':
      ensure  => 'file',
      mode    => '0700',
      owner   => 'root',
      group   => 'root',
      content => template("${module_name}/jenkins-slave.erb"),
      notify  => Service['jenkins-slave']
  }

  service { 'jenkins-slave':
    ensure     => running,
    enable     => $enable,
    hasstatus  => true,
    hasrestart => true,
  }

  Exec['get_swarm_client']
  -> Service['jenkins-slave']

  if $install_java {
      Class['java'] ->
        Service['jenkins-slave']
  }
}
