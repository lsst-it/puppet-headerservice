# Installs LSST DM Header Service
class headerservice(
  Hash $lsst_python,
  String $salpytools_install_path,
  String $salpytools_repo_path,
  String $header_service_install_path,
  String $lsst_software_install,
  String $lsst_software_repo,
  String $fitsio_source,
  String $fitsio_filename,
  Array $header_service_www_output,
  String $salpytools_git_repo,
  String $header_service_repo,
  String $header_service_repo_path,
  Array $sal_dependency_list,
  String $lsst_sal_repo_url,
  String $setup_env_path,
  String $setup_env_content,
  String $ts_sal_path,
){

  # configure the repo we want to use
  yumrepo { 'lsst_sal':
    enabled  => 1,
    descr    => 'LSST Sal Repo',
    baseurl  => $lsst_sal_repo_url,
    gpgcheck => 0,
  }

  package{'epel-release':
    ensure => installed,
  }

  # Temporary hotfix
  ###############################################
  user{ 'salmgr':
    ensure     => 'present',
    uid        => '501' ,
    gid        => '500',
    home       => '/home/salmgr',
    managehome => true,
    require    => Group['lsst'],
    password   => lookup('salmgr_pwd'),
  }

  file{ $setup_env_path:
    ensure  => file,
    content => $setup_env_content
  }

  $sal_dependency_list.each | $dependency | {
    package{ $dependency:
      ensure  => installed,
      require => Yumrepo['lsst_sal']
    }
  }

  if ! defined(Package["${lsst_python["package"]}-devel"]) {
    package{ "${lsst_python["package"]}-devel":
        ensure => installed,
    }
  }

  # Python 3 does not create major version link.
  file { "/bin/python${lsst_python["major"]}":
    ensure => link,
    target => "/bin/python${lsst_python["version"]}"
  }

  package{ "${lsst_python["package"]}-setuptools":
    ensure  => installed,
    require => Package['epel-release']
  }

  package{ "${lsst_python["package"]}-numpy":
    ensure  => installed,
    require => Package['epel-release']
  }

  package{ "${lsst_python["package"]}-pip":
    ensure  => installed,
    require => Package['epel-release']
  }

  # Installation does not create link. That causes problems in the next step.
  file { "/bin/pip${lsst_python["major"]}":
    ensure => link,
    target => "/bin/pip${lsst_python["version"]}"
  }

  package { 'PyYAML==3.13':
    ensure   => installed,
    provider => pip3,
    require  => File["/bin/pip${lsst_python["major"]}"]
  }

  package { 'astropy':
    ensure   => installed,
    provider => pip3,
    require  => File["/bin/pip${lsst_python["major"]}"],
  }

  exec { 'get-custom-fitsio':
    command => "wget ${fitsio_source} -O ${lsst_software_repo}/${fitsio_filename}.tar.gz",
    path    => '/bin/',
    #TODO Change this with a better condition
    onlyif  => "test ! -d  /usr/${lsst_python["lib_path"]}/python${lsst_python["version"]}/site-packages/fitsio*",
    require => [File[$lsst_software_repo], Vcsrepo[$salpytools_repo_path], Vcsrepo[$header_service_repo_path]]
  }
  ~>  exec{ 'install-custom-fitsio':
        path    => '/bin/:/usr/bin',
        cwd     => $lsst_software_repo,
        command => "tar xfz ${fitsio_filename}.tar.gz && cd ${fitsio_filename} && python${lsst_python["major"]} setup.py install --prefix=/usr",
        #TODO change this to a better condition
        onlyif  => "test ! -d  /usr/${lsst_python["lib_path"]}/python${lsst_python["version"]}/site-packages/fitsio*",
      }
      ~>  exec { 'Install salpytools':
            path        => '/bin',
            cwd         => $salpytools_repo_path, #$salpytools_repo_path,
            user        => 'salmgr',
            group       => 'lsst',
            command     => "/bin/python${lsst_python["major"]} setup.py install \
                            --prefix=${salpytools_install_path} \
                            --install-lib=${salpytools_install_path}/python",
            require     => [ Vcsrepo[$salpytools_repo_path], File[$salpytools_install_path], File["/bin/python${lsst_python["major"]}"]],
            refreshonly => true,
          }
          ~>  exec { 'Install HeaderService':
                path        => '/bin',
                cwd         => $header_service_repo_path,
                user        => 'salmgr',
                group       => 'lsst',
                command     => "/bin/python${lsst_python["major"]} setup.py install \
                                --prefix=${header_service_install_path} \
                                --install-lib=${header_service_install_path}/python",
                require     => [Vcsrepo[$header_service_repo_path], File[$header_service_install_path], File["/bin/python${lsst_python["major"]}"]],
                refreshonly => true,
              }
              ~>  exec { 'Create environment for HeaderService':
                    user    => 'salmgr',
                    group   => 'lsst',
                    path    => [ '/usr/bin', '/bin', '/usr/sbin' , '/usr/local/bin'],
                    command => "/bin/bash -c 'source ${ts_sal_path}/setup.env ; \
                                source ${header_service_install_path}/setpath.sh ${header_service_install_path} ; \
                                source ${salpytools_install_path}/setpath.sh ${salpytools_install_path}; \
                                source /etc/setup_sal.env; \
                                env > ${header_service_install_path}/headerservice.env'",
                    onlyif  => "test ! -f ${header_service_install_path}/headerservice.env",
                    require => [File[$header_service_install_path], File[$salpytools_install_path]]
                  }

  file { $lsst_software_install :
    ensure  => directory,
    owner   => 'salmgr',
    group   => 'lsst',
    require => [User['salmgr'] , Group['lsst']]
  }

  file { $lsst_software_repo :
    ensure  => directory,
    owner   => 'salmgr',
    group   => 'lsst',
    require => [User['salmgr'] , Group['lsst'], File[$lsst_software_install]]
  }

  file { $header_service_repo_path:
    ensure  => directory,
    owner   => 'salmgr',
    group   => 'lsst',
    recurse => true,
    require => [User['salmgr'] , Group['lsst']]
  }

  file { $salpytools_repo_path:
    ensure  => directory,
    owner   => 'salmgr',
    group   => 'lsst',
    require => [File[$lsst_software_repo]]
  }

  file { $salpytools_install_path:
    ensure  => directory,
    owner   => 'salmgr',
    group   => 'lsst',
    require => [File[$lsst_software_install] ]
  }

  vcsrepo { $salpytools_repo_path:
    ensure   => present,
    provider => git,
    source   => $salpytools_git_repo,
    revision => lookup('headerservice::salpytools_current_tag'),
    owner    => 'salmgr',
    group    => 'lsst',
    require  => [File[$lsst_software_repo]]
  }

  file { $header_service_install_path:
    ensure  => directory,
    owner   => 'salmgr',
    group   => 'lsst',
    require => [User['salmgr'] , Group['lsst'], File[$lsst_software_install]]
  }

  vcsrepo { $header_service_repo_path:
    ensure   => present,
    provider => git,
    source   => $header_service_repo,
    revision => lookup('headerservice::header_service_current_tag'),
    owner    => 'salmgr',
    group    => 'lsst',
    require  => [File[$lsst_software_repo]]
  }

  file { '/etc/systemd/system/ATHeaderService_CSC.service':
    ensure  => present,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => epp('headerservice/systemd_unit_template.epp',
      { 'serviceDescription' => 'Runner for ATHeaderService CSC',
        'startPath'          => $header_service_install_path,
        'serviceCommand'     => "/bin/python${lsst_python["major"]} ${header_service_install_path}/bin/DMHS_ATS_configurable  \
                                -c ${header_service_install_path}/etc/conf/atTelemetry.yaml \
                                --filepath ${header_service_repo_path}",
        'systemdUser'        => 'salmgr',
        'environmentFile'    => "${header_service_install_path}/headerservice.env"
      }
    ),
    notify  => Exec['Systemd daemon reload'],
    require => Exec['Create environment for HeaderService']
  }

  service { 'ATHeaderService_CSC':
    ensure  => running,
    enable  => true,
    require => [File['/etc/systemd/system/ATHeaderService_CSC.service']]
  }

  exec{ 'Systemd daemon reload':
    path        => [ '/usr/bin', '/bin', '/usr/sbin' , '/usr/local/bin'],
    command     => 'systemctl daemon-reload',
    refreshonly => true
  }
}
