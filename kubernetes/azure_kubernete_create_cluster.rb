require './kubernetes/azure_kubernete'

class AzureKuberneteCreateCluster < AzureKubernete

  attr_accessor :cluster_name
  attr_accessor :acr_name

  def initialize(resource_group, options = {})
    super
    self.cluster_name = options[:cluster_name]
    self.acr_name = options[:acr_name]
  end

  def call(options = {})
    create_container_registry
    create_cluster(options[:node_count])
    acr_authentication
    connect_kubectl
  end

  def create_container_registry
    registry = `az acr create --resource-group #{resource_group} --name #{acr_name} --sku Basic`
    puts registry
  end

  def create_cluster(node_count)
    cluster = `az aks create --resource-group #{resource_group} --name #{cluster_name} --node-count #{node_count} --generate-ssh-keys`
    puts cluster
  end

  # Documentation 
  # https://github.com/DadeSystems/DadeCore/wiki/Kubernetes-Setup-Documentation#configure-acr-authentication
  def acr_authentication
    client_id = `az aks show --resource-group #{resource_group} --name #{cluster_name} --query "servicePrincipalProfile.clientId" --output tsv`
    acr_id = `az acr show --name #{acr_name} --resource-group #{resource_group} --query "id" --output tsv`
    role_assignment = `az role assignment create --assignee #{client_id.strip} --role Reader --scope #{acr_id.strip}`
    puts role_assignment
  end

  # Documentation
  # https://github.com/DadeSystems/DadeCore/wiki/Kubernetes-Setup-Documentation#connect-with-kubectl
  def connect_kubectl
    connect = `az aks get-credentials --resource-group #{resource_group} --name #{cluster_name}`
  end

end

options = {cluster_name: APP_ENV['CLUSTER'], acr_name: APP_ENV['ACR_NAME']}
cluster = AzureKuberneteCreateCluster.new(APP_ENV['RESOURCE_GROUP'], options)
cluster.login
cluster.set_subscription(APP_ENV['SUBSCRIPTION'])
cluster.call(node_count: APP_ENV['MIN_NODES'])
