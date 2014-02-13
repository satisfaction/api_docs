require 'api_docs/version'
require 'api_docs/engine'
require 'api_docs/configuration'
require 'api_docs/test_helper'

module ApiDocs

  class << self

    attr_accessor :store_data_strategy, :file_name_strategy

    def configure
      yield configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end
    alias :config :configuration

    def store_data(api_docs, captured_data)
      strategy = store_data_strategy || method(:default_store_data)
      strategy.call(api_docs, captured_data)
    end

    def file_name(captured_data)
      strategy = file_name_strategy || method(:default_file_name)
      strategy.call(captured_data)
    end

    private

    def default_store_data(api_docs, captured_data)
      # Marking response as an unique
      key = ""
      key << captured_data['method']
      key << captured_data['path']
      key << captured_data['meta'].to_s
      key << captured_data['params'].to_s
      key << captured_data['status'].to_s
      hashed_key = 'ID-' + Digest::MD5.hexdigest(key)

      api_docs[captured_data['action']] ||= { }
      api_docs[captured_data['action']][hashed_key] = captured_data
    end

    def default_file_name(captured_data)
      "#{captured_data['controller'].gsub('/', ':')}.yml"
    end

  end
end
