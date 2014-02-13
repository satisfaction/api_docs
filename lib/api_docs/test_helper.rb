module ApiDocs::TestHelper

  module InstanceMethods
    # Method that allows test creation and will document results in a YAML file
    # Example usage:
    #   api_call(:get, '/users/:id', :id => 12345) do |doc|
    #     doc.description = 'Something for the docs'
    #     ... regular test code
    #   end
    def api_call(method, path, params = {}, headers = {})
      parsed_path   = path.dup
      parsed_params = params.dup

      parsed_params.each do |k, v|
        parsed_params.delete(k) if parsed_path.gsub!(":#{k}", v.to_s)
      end

      # Making actual test request. Based on the example above:
      #   get '/users/12345'
      send(method, parsed_path, parsed_params, headers)

      meta = Hash.new
      yield meta if block_given?

      # Not writing anything to the files unless there was a demand
      if ApiDocs.config.generate_on_demand
        return unless ENV['API_DOCS']
      end

      captured_data = {
        'controller'  => request.filtered_parameters['controller'],
        'action'      => request.filtered_parameters['action'],
        'meta'        => meta,
        'method'      => method.upcase.to_s,
        'path'        => path,
        'headers'     => headers,
        'params'      => ApiDocs::TestHelper.api_deep_clean_params(params),
        'status'      => response.status,
        'body'        => response.body
      }

      read_api_docs(captured_data) if ApiDocs.automatic_write?
      ApiDocs.store_data(captured_data)
      write_api_docs(captured_data) if ApiDocs.automatic_write?
    end

    def read_api_docs(captured_data)
      calculated_file_path = file_path(captured_data)
      ApiDocs.docs = if File.exists?(calculated_file_path)
        YAML.load_file(calculated_file_path) rescue Hash.new
      else
        Hash.new
      end
    end

    def file_path(captured_data)
      File.expand_path(file_name(captured_data), ApiDocs.config.docs_path)
    end

    def file_name(captured_data)
      "#{captured_data['controller'].gsub('/', ':')}.yml"
    end

    def write_api_docs(captured_data)
      calculated_file_path = file_path(captured_data)
      FileUtils.mkdir_p(File.dirname(calculated_file_path))
      File.open(calculated_file_path, 'w') {|f| f.write(ApiDocs.docs.to_yaml)}
    end

  end

  # Cleans up params. Removes things like File object handlers
  # Sets up ignored values so we don't generate new keys for same data
  def self.api_deep_clean_params(params)
    case params
    when Hash
      params.each_with_object({}) do |(key, value), res|
        res[key.to_s] = api_deep_clean_params(value)
      end
    when Array
      params.collect{|value| api_deep_clean_params(value)}
    else
      case params
      when Rack::Test::UploadedFile
        'BINARY'
      else
        params.to_s
      end
    end
  end
end

ActionDispatch::IntegrationTest.send :include, ApiDocs::TestHelper::InstanceMethods
