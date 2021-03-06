
describe 'glance::registry' do

  let :facts do
    {
      :osfamily => 'Debian'
    }
  end

  let :default_params do
    {
      :verbose           => false,
      :debug             => false,
      :bind_host         => '0.0.0.0',
      :bind_port         => '9191',
      :log_file          => '/var/log/glance/registry.log',
      :sql_connection    => 'sqlite:///var/lib/glance/glance.sqlite',
      :sql_idle_timeout  => '3600',
      :enabled           => true,
      :auth_type         => 'keystone',
      :auth_host         => '127.0.0.1',
      :auth_port         => '35357',
      :auth_protocol     => 'http',
      :keystone_tenant   => 'admin',
      :keystone_user     => 'admin',
      :keystone_password => 'ChangeMe',
    }
  end

  [
    {:keystone_password => 'ChangeMe'},
    {
      :verbose           => true,
      :debug             => true,
      :bind_host         => '127.0.0.1',
      :bind_port         => '9111',
      :log_file          => '/var/log/glance-registry.log',
      :sql_connection    => 'sqlite:///var/lib/glance.sqlite',
      :sql_idle_timeout  => '360',
      :enabled           => false,
      :auth_type         => 'keystone',
      :auth_host         => '127.0.0.1',
      :auth_port         => '35357',
      :auth_protocol     => 'http',
      :keystone_tenant   => 'admin',
      :keystone_user     => 'admin',
      :keystone_password => 'ChangeMe',
    }
  ].each do |param_set|

    describe "when #{param_set == {:keystone_password => 'ChangeMe'} ? "using default" : "specifying"} class parameters" do
      let :param_hash do
        default_params.merge(param_set)
      end

      let :params do
        param_set
      end

      it { should contain_class 'glance::registry' }

      it { should contain_service('glance-registry').with(
          'ensure'     => param_hash[:enabled] ? 'running' : 'stopped',
          'enable'     => param_hash[:enabled],
          'hasstatus'  => true,
          'hasrestart' => true,
          'subscribe'  => 'File[/etc/glance/glance-registry.conf]',
          'require'    => 'Class[Glance]'
      )}

      it 'should only sync the db if the service is enabled' do

        if param_hash[:enabled]
          should contain_exec('glance-manage db_sync').with(
            'path'        => '/usr/bin',
            'refreshonly' => true,
            'logoutput'   => 'on_failure',
            'subscribe'   => ['Package[glance]', 'File[/etc/glance/glance-registry.conf]'],
            'notify'      => 'Service[glance-registry]'
          )
        end
      end
      it 'should configure itself' do
        [
         'verbose',
         'debug',
         'bind_port',
         'bind_host',
         'sql_connection',
         'sql_idle_timeout'
        ].each do |config|
          should contain_glance_registry_config("DEFAULT/#{config}").with_value(param_hash[config.intern])
        end
        [
         'auth_host',
         'auth_port',
         'auth_protocol'
        ].each do |config|
          should contain_glance_registry_config("keystone_authtoken/#{config}").with_value(param_hash[config.intern])
        end
        should contain_glance_registry_config('keystone_authtoken/auth_admin_prefix').with_ensure('absent')
        if param_hash[:auth_type] == 'keystone'
          should contain_glance_registry_config("paste_deploy/flavor").with_value('keystone')
          should contain_glance_registry_config("keystone_authtoken/admin_tenant_name").with_value(param_hash[:keystone_tenant])
          should contain_glance_registry_config("keystone_authtoken/admin_user").with_value(param_hash[:keystone_user])
          should contain_glance_registry_config("keystone_authtoken/admin_password").with_value(param_hash[:keystone_password])
        end
      end
    end
  end

  describe 'with overridden pipeline' do
    # At the time of writing there was only blank and keystone as options
    # but there is no reason that there can't be more options in the future.
    let :params do
      {
        :keystone_password => 'ChangeMe',
        :pipeline          => 'validoptionstring',
      }
    end

    it { should contain_glance_registry_config('paste_deploy/flavor').with_value('validoptionstring') }
  end

  describe 'with blank pipeline' do
    let :params do
      {
        :keystone_password => 'ChangeMe',
        :pipeline          => '',
      }
    end

    it { should contain_glance_registry_config('paste_deploy/flavor').with_ensure('absent') }
  end

  [
    'keystone/',
    'keystone+',
    '+keystone',
    'keystone+cachemanagement+',
    '+'
  ].each do |pipeline|
    describe "with pipeline incorrect value #{pipeline}" do
      let :params do
        {
          :keystone_password => 'ChangeMe',
          :auth_type         => 'keystone',
          :pipeline          => pipeline
        }
      end

      it { expect { should contain_glance_registry_config('filter:paste_deploy/flavor') }.to\
        raise_error(Puppet::Error, /validate_re\(\): .* does not match/) }
    end
  end

  describe 'with overriden auth_admin_prefix' do
    let :params do
      {
        :keystone_password => 'ChangeMe',
        :auth_admin_prefix => '/keystone/main'
      }
    end

    it { should contain_glance_registry_config('keystone_authtoken/auth_admin_prefix').with_value('/keystone/main') }
  end

  [
    '/keystone/',
    'keystone/',
    'keystone',
    '/keystone/admin/',
    'keystone/admin/',
    'keystone/admin'
  ].each do |auth_admin_prefix|
    describe "with auth_admin_prefix_containing incorrect value #{auth_admin_prefix}" do
      let :params do
        {
          :keystone_password => 'ChangeMe',
          :auth_admin_prefix => auth_admin_prefix
        }
      end

      it { expect { should contain_glance_registry_config('filter:authtoken/auth_admin_prefix') }.to\
        raise_error(Puppet::Error, /validate_re\(\): "#{auth_admin_prefix}" does not match/) }
    end
  end
end
