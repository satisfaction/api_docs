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
            
      # Not writing anything to the files unless there was a demand
      if ApiDocs.config.generate_on_demand
        return unless ENV['API_DOCS']
      end
      
      meta = Hash.new
      yield meta if block_given?
      
      # Assertions inside test block didn't fail. Preparing file
      # content to be written
      c      = request.filtered_parameters['controller'].gsub('/', ':')
      a      = request.filtered_parameters['action']
      params = ApiDocs::TestHelper.api_deep_clean_params(params)
         
      # # Marking response as an unique
      key = 'ID-' + Digest::MD5.hexdigest("
        #{method}#{path}#{meta}#{params}#{response.status}}
      ")

      api_docs[c]||= { }
      api_docs[c][a] ||= { }
      api_docs[c][a][key] = {
        'meta'        => meta,
        'method'      => request.method,
        'path'        => path,
        'headers'     => headers,
        'params'      => ApiDocs::TestHelper.api_deep_clean_params(params),
        'status'      => response.status,
        'body'        => response.body
      }
    end

    def api_docs
      @api_docs
    end

    def write_api_docs
      api_docs.each do |controller, api_calls|
        file_path = File.expand_path("#{controller}.yml", ApiDocs.config.docs_path)
        FileUtils.mkdir_p(File.dirname(file_path))
        File.open(file_path, 'w'){|f| f.write(api_calls.to_yaml)}
      end
    end

    def read_api_docs
      docs = {}
      Dir["#{ApiDocs.config.docs_path}/*.yml"].each do |file_path|
        docs[File.basename(file_path, '.yml')] = YAML.load_file(file_path) rescue Hash.new
      end
      @api_docs = docs
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
ActionDispatch::IntegrationTest.add_setup_hook { read_api_docs }
ActionDispatch::IntegrationTest.add_setup_hook { write_api_docs }
