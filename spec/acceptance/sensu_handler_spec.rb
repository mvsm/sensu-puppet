require 'spec_helper_acceptance'

describe 'sensu_handler', :unless => UNSUPPORTED_PLATFORMS.include?(fact('osfamily')) do
  node = only_host_with_role(hosts, 'sensu_backend')
  context 'default' do
    it 'should work without errors' do
      pp = <<-EOS
      include ::sensu::backend
      sensu_handler { 'test':
        type          => 'pipe',
        command       => 'notify.rb'
      }
      EOS

      # Run it twice and test for idempotency
      apply_manifest_on(node, pp, :catch_failures => true)
      apply_manifest_on(node, pp, :catch_changes  => true)
    end

  end
end

