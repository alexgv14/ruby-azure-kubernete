require './kubernetes/azure_kubernete'
require 'redis'
require 'resque'

class AzureKuberneteResque < AzureKubernete

  attr_accessor :redis

  def initialize
    self.redis = connect
  end

  def connect
    Redis.new(host: AzureKuberneteResque.const_defined?("APP_ENV") ? APP_ENV['REDIS_HOST'] : nil, 
              port: 6379, 
              db: 0, 
              password: AzureKuberneteResque.const_defined?("APP_ENV") ? APP_ENV['REDIS_PASSWORD'] : nil)
  end

  def get(key)
    redis.get(key)
  end

  def set(key, value)
    redis.set(key, value)
  end

  def status(queues = {})
    Resque.redis = redis
    Resque.queues.each { |q| queues[q.to_sym] = Resque.size(q) }
    queues
  end

  def size(queue)
    Resque.redis = redis
    Resque.size(queue)
  end


end