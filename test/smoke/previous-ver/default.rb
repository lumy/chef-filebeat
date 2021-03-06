# # encoding: utf-8

# Inspec test for recipe filebeat::v6

# The Inspec reference, with examples and extensive documentation, can be
# found at http://inspec.io/docs/reference/resources/

if %w(redhat fedora amazon).include?(os[:family])
  describe file('/etc/yum.repos.d/elastic6.repo') do
    its('content') { should match %r{https://artifacts.elastic.co/packages/6.x/yum} }
  end
else
  describe file('/etc/apt/sources.list.d/elastic6.list') do
    its('content') { should match %r{https://artifacts.elastic.co/packages/6.x/apt} }
  end
end

describe file('/etc/filebeat/filebeat.yml') do
  it { should exist }
  # its('content') { should match 'filebeat.config.inputs' }
end

describe command('filebeat test config') do
  its('exit_status') { should eq 0 }
  its('stdout') { should match 'Config OK' }
end

describe package('filebeat') do
  it { should be_installed }
  its('version') { should match '6.8.8' }
end

if %w(16.04 2 7).include?(os[:release])
  describe systemd_service('filebeat') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end
else
  describe service('filebeat') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end
end
