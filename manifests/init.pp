#
# = Class: openshiftinstaller
#
# == Summary
#
# Installs openshift in an BYO (bring-your-own) configuration on a list of hosts.
# The host list is generated with information from puppetdb.
#
# Please see README.md for details.
#
#
class openshiftinstaller (
  $playbooksrc        = 'https://github.com/openshift/openshift-ansible.git',
  $playbookversion    = '__UNSET__',

  # for collecting from puppet db
  $query_fact         = 'role',
  $master_value       = 'openshift-master',
  $minion_value       = 'openshift-minion',
  $cluster_name_fact  = 'openshift_cluster_name',
  $install_type       = 'automatic',

  # inventory variable settings
  $deployment_type    = 'origin',
  $additional_repos   = [],
  $registry_url       = '__UNSET__',
) {

  validate_re($deployment_type, '^(origin|enterprise)$',
    "openshiftinstaller - Wrong value for \$deployment_type '${deployment_type}'. Must be in (origin|enterprise)")
  validate_re($install_type, '^(automatic|manual)$',
    "openshiftinstaller - Wrong value for \$install_type '${install_type}'. Must be in (automatic|manual)")
  validate_array($additional_repos)

  # default config is "master", you have to configure nodes explicitly
  include ansible
  include ansible::playbooks

  # install the check fact
  file { '/etc/facter/facts.d/osi_puppetdb_running.py':
    ensure  => 'present',
    source  => 'puppet:///modules/openshiftinstaller/osi_puppetdb_running.py',
    mode    => '0755',
  }

  if $::osi_puppetdb_running == 'yes' {

    Class['::ansible::playbooks'] -> Class['openshiftinstaller']

    $ansible_basedir   = $::ansible::playbooks::location
    $inventory_basedir = "${ansible_basedir}/openshift_inventory"
    $playbook_dirname  = 'openshift_playbook'
    $playbook_basedir  = "${ansible_basedir}/${playbook_dirname}"

    file { $inventory_basedir:
      ensure  => directory,
      owner   => root,
      group   => root,
      mode    => '0755',
      purge   => true,
      force   => true,
      recurse => true,
      ignore  => 'cluster_*_success',
      source  => 'puppet:///modules/openshiftinstaller/EMPTY_DIR',
    }

    $masters_clusters = query_facts(
      "${query_fact}=\"${master_value}\"",
      [ $cluster_name_fact ])

    $nodes_clusters = query_facts(
      "${query_fact}=\"${minion_value}\"",
      [ $cluster_name_fact ])

    $invfiles = {}
    $cluster_names = []

    # this is again black inline template magic. we should enable the future
    # parser for this, or write a custom function (but then we run into the
    # environment problems ...)
    $discard_me = inline_template('<%

      @masters_clusters.each { |nodename, nodefacts|
        cluster_name = nodefacts[@cluster_name_fact]
        @cluster_names << cluster_name
        @invfiles[cluster_name] ||= {}
        cluster = @invfiles[cluster_name]
        cluster["masters"] ||= []
        cluster["masters"] << nodename
      }

      @cluster_names.uniq!
      @cluster_names.sort!

      @nodes_clusters.each { |nodename, nodefacts|
        cluster_name = nodefacts[@cluster_name_fact]
        # we only create clusters which have masters :)
        # no idea if this is actually useful, but lets just be sure.
        continue unless @invfiles.has_key? cluster_name
        # lets go on.
        cluster = @invfiles[cluster_name]
        cluster["nodes"] ||= []
        cluster["nodes"] << nodename
      }

    %>')

    # finally, let's create it ;)
    create_resources('openshiftinstaller::invfile',
                      $invfiles,
                      { 'basedir' => $inventory_basedir })

    Invfile<||> -> Exec['clone openshift-ansible']

    $cmdline_select_branch = $playbookversion ? {
      '__UNSET__' => '',
      default     => " -b ${playbookversion}",
    }

    exec { 'clone openshift-ansible':
      command => "/usr/bin/git clone ${playbooksrc}${cmdline_select_branch} --single-branch ${playbook_dirname}",
      cwd     => $ansible_basedir,
      unless  => "/usr/bin/test -d '${playbook_basedir}'",
    }

    Exec['clone openshift-ansible'] -> Installcluster<||>

    # we only install clusters for which we found a master (in the magic template
    # above we only add the cluster name to $cluster_names from the master hosts)
    if $install_type == 'automatic' {
      installcluster { $cluster_names: }
    }

  }

}
