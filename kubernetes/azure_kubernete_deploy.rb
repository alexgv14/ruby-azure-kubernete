require './kubernetes/azure_kubernete_container'
require 'yaml'

class AzureKuberneteDeploy < AzureKuberneteContainer

  def initialize(resource_group, options = {})
    super
  end

  def call(options = {})
    container_login
    build_container(options[:dockerfile])
    push_container
    update_yaml(options[:yaml], options[:min_pods].to_i)
    deploy(options[:yaml])
  end

  def deploy(yaml)
    deploy = `kubectl apply -f #{yaml}`
    puts deploy
    return false unless deploy.include? "configured"
    true
  end

  def update_yaml(yaml, replicas = 2)
    puts "Deploying yaml file..."
    yaml_file = YAML.load_file(yaml)
    yaml_file['spec']['replicas'] = replicas
    yaml_file['spec']['template']['spec']['containers'].each_with_index do |item, index|
      yaml_file['spec']['template']['spec']['containers'][index]['image'] = "#{container_registry_url}/#{tag}:v#{version}"
    end
    File.open(yaml, 'w') {|f| f.write yaml_file.to_yaml }
    return true
  end

end

if ARGV[0] && ENV['RAILS_ENV'] != 'test'
  deployment = ARGV[0].downcase.strip
  puts "Starting #{deployment} deployment"
  options = 
  {
    container_registry_name: APP_ENV['CONTAINER_REGISTRY_NAME'], 
    container_registry_url: APP_ENV['CONTAINER_REGISTRY_URL'], 
    tag: "#{deployment}-dadecore", 
    app_root: APP_ENV['APP_ROOT'],
    yaml: APP_ENV["#{deployment.upcase}_YAML"],
    min_pods: APP_ENV["MIN_PODS"],
    dockerfile: APP_ENV['DOCKER_FILE'],
  }
  deploy = AzureKuberneteDeploy.new(APP_ENV['RESOURCE_GROUP'], options)
  deploy.login
  deploy.set_subscription(APP_ENV['SUBSCRIPTION'])
  deploy.call(options)
  puts "Finished #{deployment} deployment run 'kubectl get pods --watch' to see status"
end
