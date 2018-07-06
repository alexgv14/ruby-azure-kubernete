require './kubernetes/azure_kubernete_deploy'
require './kubernetes/azure_kubernete_resque'

class AzureKuberneteScale < AzureKubernete

  attr_accessor :options

  def initialize(resource_group, options = {})
    super
    self.options = options
  end

  def resque
    AzureKuberneteResque.new
  end

  def node_count
    resque.get("nodes").to_i || 0
  end

  def set_node_count(nodes)
    resque.set("nodes", nodes)
  end

  def large_queue?
    options[:queues].each do |queue|
      return true if resque.size(queue).to_i > options[:large_queue]
    end
    false
  end

  def no_queue?
    options[:queues].each do |queue|
      return false if resque.size(queue).to_i > 0
    end
    true
  end

  def az_scale_nodes(nodes)
    begin
      puts "Scaling to #{nodes} nodes..."
      response = `az aks scale --name #{options[:cluster]} --resource-group #{resource_group} --node-count #{nodes}`
      return false if JSON.parse(response)["agentPoolProfiles"].first["count"].to_i != nodes
      response
    rescue JSON::ParserError
      return false
    end
  end

  def update_yaml(pods)
    AzureKuberneteDeploy.new(resource_group, options)
      .update_yaml(options[:yaml], pods)
  end

  def az_scale_pods
    AzureKuberneteDeploy.new(resource_group, options)
      .deploy(options[:yaml])
  end

  def up
    if large_queue? && node_count < options[:max_nodes]
      if az_scale_nodes(options[:max_nodes])
        update_yaml(options[:max_pods])
        az_scale_pods
        set_node_count(options[:max_nodes])
        sleep options[:wait_time]
        return true
      end
    end
  end

  #######
  # Checks that there is nothing in the queue and nodes are less then min node.
  # THen decreases node count and checks that scaling pods and scaling nodes worked if not 
  # it returns false and will continue to try again on the next loop if it did work 
  # recursively calls down until min nodes is reached
  #######
  def down(decrease_by = 4, total)
    if no_queue? && node_count > options[:min_nodes]
      total -= decrease_by
      if total > options[:min_nodes] 
        update_yaml(total)
        if az_scale_pods && az_scale_nodes(total)
          set_node_count(total)
          sleep options[:wait_time]
          down(decrease_by, total)
        else
          return false
        end
      else 
        update_yaml(options[:min_pods])
        if az_scale_pods && az_scale_nodes(options[:min_nodes])
          set_node_count(options[:min_nodes])
        else
          return false
        end
        return true
      end
    end
  end

end

if ENV['RAILS_ENV'] != 'test'
  #######
  # Keep a min. of 3 nodes
  # Keep two pods for every core webservers take up 2 cores
  # Keep a min. of 3 pods
  # Keep a min. of at least 60 seconds setting higher will increase cool down period
  # Once a queue size gets to 1000 kubernete scales up
  # Cool down takes about 30 min with decrease_by equal to 4 with 12 nodes
  #######
  options = {
    container_registry_name: APP_ENV['CONTAINER_REGISTRY_NAME'],
    container_registry_url: APP_ENV['CONTAINER_REGISTRY_URL'],
    tag: APP_ENV['TAG'],
    app_root: APP_ENV['APP_ROOT'],
    cluster: APP_ENV['CLUSTER'],
    max_nodes: APP_ENV['MAX_NODES'].to_i,
    min_nodes: APP_ENV['MIN_NODES'].to_i,
    max_pods: APP_ENV['MAX_PODS'].to_i,
    min_pods: APP_ENV['MIN_PODS'].to_i,
    wait_time: APP_ENV['WAIT_TIME'].to_i,
    large_queue: APP_ENV['LARGE_QUEUE'].to_i,
    decrease_by: APP_ENV['DECREASE_BY'].to_i, 
    deployment: APP_ENV['DEPLOYMENT'],
    queues: APP_ENV['QUEUES'].split(',').map(&:to_sym),
    daemonize: APP_ENV['DAEMONIZE'] == "true" ? true : false,
    yaml: APP_ENV['SNAPPER_YAML'],
  }
  scale = AzureKuberneteScale.new(APP_ENV['RESOURCE_GROUP'], options)

  if options[:daemonize]
    begin
      pid_file = File.open(".azure_kubernete_scale.pid", "rb")
      pid_id = pid_file.read
      Process.getpgid(pid_id.strip.to_i)
      abort("Azure kubernete scaler is already running")
    rescue Errno::ESRCH
      Process.daemon(true)
      Process.setproctitle("azure_scaler")

      # write pid to a .pid file
      pid_file = ".azure_kubernete_scale.pid"
      File.open(pid_file, 'w') { |f| f.write Process.pid }
    end
  end

  loop do
    scale.down(options[:decrease_by], options[:max_nodes])
    scale.up
    sleep 5
  end
end

