# openshiftinstaller class for Puppet

## Summary

This class will use ansible to install openshift v3 clusters in a network (using the official RedHat openshift installer playbook). The puppet db must run on the same host (localhost), currently.


## Setup

For using this class you must have ...

* a central node which functions as ansible master
* several nodes which should be openshift masters or minions
  * the designated openshift nodes must have two facts configured:
    * one fact to indicate which role they have (OS master or minion)
    * another fact to incdicate the cluster they belong to (a simple name is all right)

## Hiera keys

If you want to set properties in the inventory files, you can do so for all clusters (using openshiftinstaller::invfile_properties hash), or cluster-specific using a hiera entry:

    openshiftinstaller::invfile::CLUSTER_NAME::properties:
      this_sets: properties for only the inventory file for for the cluster 'CLUSTER_NAME'

Properties set through `openshiftinstaller::properties` are always applied to any cluster inventory file (they are merged with cluster specific property settings using the `merge()` function from stdlib).

## Example

Let's assume the PuppetDB is running on host `central`. The hosts `os11`, `os12`, `os01`, `os02` are designated openshift nodes, where os1x and os0x should have the same cluster.

All four openshift hosts have the facts `role` and `openshift_cluster_name` configured. `role` is either `openshift-master` or `openshift-minion`.

Given that you would call the module like this:

    # these are also by pure chance the default values ;)

    class { 'openshiftinstaller':
        query_fact          => 'role',
        master_value        => 'openshift-master',
        minion_value        => 'openshift-minion',
        cluster_name_fact   => 'openshift_cluster_name',

        # the only REQUIRED parameter so far
        registry_url        => 'some://url',
    }

It would then ...

* query all nodes and their `$query_fact` (`role` in this case) and `$cluster_name_fact` (`openshift_cluster_name` in this case) using the puppetdb
* screen the `role` fact for the given master- and minion values
* sort the remaining hosts using the `openshift_cluster_name` fact
* create an ansible inventory file under `/etc/ansible/openshift_inventories`
* clone the ansible installation playbook to `/etc/ansible/openshift_playbook`
* execute the ansible installation playbook one time for each cluster with the cluster's inventory file

... or in short:

* create `/etc/ansible/openshift_inventories/cluster_<CLUSTERNAME>`, containing all nodes which have `$ openshift_cluster_name == <CLUSTERNAME>` (sorted into the `[masters]` and `[nodes]` depending on the value of `$role`)
* execute ansible with each inventory file


## Good to know

* The ansible playbook is checked out only once. Updates have to be done manually.
* We do not allow for different cluster configurations right now. It's a one-config-for-all situation. 
* The module will only run ansible for clusters for which a master is found (the cluster inventory file is always created nonetheless).
* The module will try to create the cluster until ansible ran through successfully one time
* The module will install a dynamic fact called `osi_puppetb_running`, which can be `yes` or `no`. If it is anything other than `yes` the installer will not run.
  * The fact is currently checking the puppetdb on `http://localhost:8080/v3`, which is the reason that the PuppetDB must run on the same host. This really should change.


## Internal mechanisms

The installer will work under `/etc/ansible` (default value, taken directly out of the ansible module), more precisely in the directories `/etc/ansible/openshift_playbook` and `/etc/ansible/openshift_inventories`.

The first is the target directory for the checked-out ansible playbook from github.

The second is the place for the inventory files.

Cluster installation is triggered in two cases:

  1. puppet detects a change of the cluster's inventory file (`/etc/ansible/openshift_inventory/cluster_<CLUSTERNAME>` by default)
  2. the "successful installation" check file is not present (`/etc/ansible/openshift_inventory/cluster_<CLUSTERNAME>_success`)

The "successful installation" check file is created if an ansible run for a cluster was successful, and is also automatically deleted on any change of the cluster's inventory file.


## CHANGES

* 2016-05-26: merged changed from jkhelil, adding load balancer groups and node labels


## Requirements

* nvogel/ansible
* dalen/puppetdbquery
* puppetlabs/stdlib
