require 'spec_helper'

describe 'openshiftinstaller' do

  let(:params) {{
      :registry_url => "my_url",
  }}
  let(:facts){{
    :operatingsystemfamily => 'Redhat',
    :test_and_dont_run     => true,
  }}
  it { should contain_class('ansible') }
  it { should contain_class('ansible::playbooks').\
    that_comes_before('Class[openshiftinstaller]') }

  it { should contain_openshiftinstaller__invfile('cluster0').with({
    'basedir' => '/etc/ansible/openshift_inventory',
    'masters' => [ 'ma01.t.d', 'ma02.t.d' ],
    'nodes'   => [ 'mi01.t.d', 'mi02.t.d' ],
  }) }

  it { should contain_openshiftinstaller__invfile('cluster1').with({
    'basedir' => '/etc/ansible/openshift_inventory',
    'masters' => [ 'ma11.t.d', 'ma12.t.d' ],
    'nodes'   => [ 'mi11.t.d', 'mi12.t.d' ],
  }) }

  it { should contain_class('ansible') }
  it { should contain_class('ansible::playbooks') }

end
