require 'yaml'
require 'json'

APP_ENV = YAML.load_file('./config/application.yml') if ENV['RAILS_ENV'] != 'test'

class AzureKubernete

  attr_accessor :resource_group
  attr_accessor :app_root

  # resource_group the resource group in azure where the container registry lives
  def initialize(resource_group, options = {})
    self.resource_group = resource_group
    self.app_root = options[:app_root]
  end

  def login
    login = `az login`
    puts login
  end

  def set_subscription(subscription)
    subscription = `az account set --subscription #{subscription}`
    puts subscription
  end

  def create_resource_group(location = 'eastus')
    resource_group = `az group create --name #{resource_group} --location #{location}`
    puts resource_group
  end

  def version
    version = File.read("#{app_root}/VERSION")
    version.strip
  end

end