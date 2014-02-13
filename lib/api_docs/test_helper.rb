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

      @captured_data = {
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

      ApiDocs.store_data(api_docs, @captured_data)

      write_docs
    end

    def api_docs
      @api_docs ||= if File.exists?(file_path)
        YAML.load_file(file_path) rescue Hash.new
      else
        Hash.new
      end
    end

    def file_name
      ApiDocs.file_name(@captured_data)
    end

    def file_path
      File.expand_path(file_name, ApiDocs.config.docs_path)
    end

    def write_docs
      FileUtils.mkdir_p(File.dirname(file_path))
      File.open(file_path, 'w'){|f| f.write(api_docs.to_yaml)}
    end
  end

  # Cleans up params. Removes things like File object handlers
  # Sets up ignored values so we don't generate new keys for same data
  def self.api_deep_clean_params(params)
    case params
    when Hash
      params.each_with_object({}) do |(key, value), res|
        res[key.to_s] = ApiDocs::TestHelper.api_deep_clean_params(value)
      end
    when Array
      params.collect{|value| ApiDocs::TestHelper.api_deep_clean_params(value)}
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
