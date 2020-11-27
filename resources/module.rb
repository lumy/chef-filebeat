# coding: utf-8
#
# Cookbook:: filebeat
# Resource:: filebeat_prospector
#

resource_name :filebeat_module

property :service_name, String, default: 'filebeat'
property :module_name, String
property :filebeat_install_resource_name, String, default: 'default'
property :config, [Array, Hash], default: {}
property :cookbook_file_name, [String, NilClass]
property :cookbook_file_name_cookbook, [String, NilClass]
property :disable_service, [true, false], default: false
property :notify_restart, [true, false], default: true
property :config_sensitive, [true, false], default: false

default_action :update

action :update do
  install_preview_resource = check_beat_resource(Chef.run_context, :filebeat_install_preview, new_resource.filebeat_install_resource_name)
  install_resource = check_beat_resource(Chef.run_context, :filebeat_install, new_resource.filebeat_install_resource_name)
  filebeat_install_resource = install_preview_resource || install_resource
  raise "could not find resource filebeat_install[#{new_resource.filebeat_install_resource_name}] or filebeat_install_preview[#{new_resource.filebeat_install_resource_name}]" if filebeat_install_resource.nil?

  config = new_resource.config.dup
  config = [config] unless new_resource.config.is_a?(Array)
  module_name = new_resource.module_name

  if not config[0]['enabled']
    deactivate_module module_name, filebeat_install_resource.modules_dir
    return
  end
  config[0].delete('enabled')
  # Filebeat and psych v1.x don't get along.
  if Psych::VERSION.start_with?('1')
    defaultengine = YAML::ENGINE.yamler
    YAML::ENGINE.yamler = 'syck'
  end
  config[0] = {'module': module_name}.merge(config[0])
  file_content = JSON.parse(config.to_json).to_yaml.lines.to_a[1..-1].join

  # ...and put this back the way we found them.
  YAML::ENGINE.yamler = defaultengine if Psych::VERSION.start_with?('1')

  module_file_name = "#{new_resource.module_name}.yml"

  # Remove the .disabled file.
  file "module_#{new_resource.name}.disabled" do
    path "#{::File.join(filebeat_install_resource.modules_dir, module_file_name)}.disabled"
    action :delete
  end

  if new_resource.cookbook_file_name && new_resource.cookbook_file_name_cookbook
    cookbook_file "module_#{new_resource.name}" do
      path ::File.join(filebeat_install_resource.modules_dir, module_file_name)
      source new_resource.cookbook_file_name
      cookbook new_resource.cookbook_file_name_cookbook
      notifies :restart, "service[#{new_resource.service_name}]" if new_resource.notify_restart && !new_resource.disable_service
      mode '600'
      sensitive new_resource.config_sensitive
    end
  else
    file "module_#{new_resource.name}" do
      path ::File.join(filebeat_install_resource.modules_dir, module_file_name)
      content file_content
      notifies :restart, "service[#{new_resource.service_name}]" if new_resource.notify_restart && !new_resource.disable_service
      mode '600'
      sensitive new_resource.config_sensitive
    end
  end

end



action_class do
  include ::Filebeat::Helpers
end
