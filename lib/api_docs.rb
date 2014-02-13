require 'api_docs/version'
require 'api_docs/engine'
require 'api_docs/configuration'
require 'api_docs/test_helper'

module ApiDocs

  class << self

    attr_accessor :store_data_strategy, :file_name_strategy, :docs,
      :automatic_write

    def configure
      yield configuration
    end

    def automatic_write?
      self.automatic_write.nil? ? true : self.automatic_write
    end

    def configuration
      @configuration ||= Configuration.new
    end
    alias :config :configuration

    def store_data(captured_data)
      strategy = store_data_strategy || method(:default_store_data)
      strategy.call(docs, captured_data, default_key(captured_data))
    end

    def docs
      @docs ||= Hash.new
    end

    private

    def default_store_data(api_docs, captured_data, key)
      api_docs[captured_data['action']] ||= { }
      api_docs[captured_data['action']][key] = captured_data
    end

    # Marking response as an unique
    def default_key(captured_data)
      key = ""
      key << captured_data['method']
      key << captured_data['path']
      key << captured_data['meta'].to_s
      key << captured_data['params'].to_s
      key << captured_data['status'].to_s
      'ID-' + Digest::MD5.hexdigest(key)
    end

    def default_file_name(captured_data)
      "#{captured_data['controller'].gsub('/', ':')}.yml"
    end

  end
end
