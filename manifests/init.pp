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
){

  include ts_sal
  $ts_sal_path = lookup('ts_sal::ts_sal_path')

  class{ 'ts_xml':
    ts_xml_path       => lookup('ts_xml::ts_xml_path'),
    ts_xml_subsystems => lookup('headerservice::ts_xml_subsystems'),
    ts_xml_languages  => lookup('headerservice::ts_xml_languages'),
    ts_sal_path       => $ts_sal_path,
    require           => Class['ts_sal']
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
    require => [File[$lsst_software_repo], Vcsrepo[$salpytools_repo_path], Vcsrepo[$dmhs_repo_path]]
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
                cwd         => $dmhs_repo_path,
                user        => 'salmgr',
                group       => 'lsst',
                command     => "/bin/python${lsst_python["major"]} setup.py install \
                                --prefix=${dmhs_install_path} \
                                --install-lib=${dmhs_install_path}/python",
                require     => [Vcsrepo[$dmhs_repo_path], File[$dmhs_install_path], File["/bin/python${lsst_python["major"]}"]],
                refreshonly => true,
              }
              ~>  exec { 'Create environment for HeaderService':
                    user    => 'salmgr',
                    group   => 'lsst',
                    path    => [ '/usr/bin', '/bin', '/usr/sbin' , '/usr/local/bin'],
                    command => "/bin/bash -c 'source ${ts_sal_path}/setup.env ; \
                                source ${dmhs_install_path}/setpath.sh ${dmhs_install_path} ; \
                                source ${salpytools_install_path}/setpath.sh ${salpytools_install_path}; \
                                env > ${dmhs_install_path}/headerservice.env'",
                    onlyif  => "test ! -f ${dmhs_install_path}/headerservice.env",
                    require => [File[$dmhs_install_path], File[$salpytools_install_path]]
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
    source   => $dmhs_git_repo,
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
                                --filepath ${header_service_repo_path[1]}",
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
