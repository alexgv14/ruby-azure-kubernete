require './kubernetes/azure_kubernete'
require 'yaml'

class AzureKuberneteContainer < AzureKubernete

  attr_accessor :container_registry_name
  attr_accessor :container_registry_url
  attr_accessor :tag

  # Documentation
  # https://github.com/DadeSystems/DadeCore/wiki/Kubernetes-Setup-Documentation#docker-for-containerizing-our-app
  # container_registry_name is the azure container registry name
  # container_registry_url is the azure url to pull down container
  # tag is used for tagging the docker image
  def initialize(resource_group, options = {})
    super
    self.container_registry_name = options[:container_registry_name]
    self.container_registry_url = options[:container_registry_url]
    self.tag = options[:tag]
  end

  def container_login
    login = `az acr login --name #{container_registry_name}`
    puts login
  end

  def build_container(docker_file)
    puts "Building container..."
    Dir.chdir(app_root){
      build = `docker build -t #{tag} -f #{docker_file} .`
      puts build
    }
  end

  def push_container
    puts "Pushing container to registry..."
    docker_tag = `docker tag #{tag} #{container_registry_url}/#{tag}:v#{version}`
    push = `docker push #{container_registry_url}/#{tag}:v#{version}`
    puts push
  end

end