require 'yard'
require 'json'

MCP_TOOL_TAG = :"mcp.tool"
YARD::Tags::Library.define_tag("MCP Tool", MCP_TOOL_TAG)

module SchnellMCP
  class Server
    def initialize(file_path, interactive: true)
      @file_path = file_path
      @interactive = interactive
      @mcp_methods = {}
      parse_file
    end

    def self.run(file_path)
      new(file_path).start
    end

    def start
      @interactive ? start_interactive : self
    end

    def send_request(request)
      handle_request(request)
    end

    private

    def parse_file
      code = File.read(@file_path)
      
      YARD.parse_string(code)
      
      YARD::Registry.all(:method).each do |method|
        next unless method.has_tag?(MCP_TOOL_TAG)
        
        @mcp_methods[method.name.to_s] = {
          description: method.docstring.summary || method.docstring.to_s,
          parameters: method.tags(:param).map do |tag|
            {
              name: tag.name,
              type: tag.types ? tag.types.join(', ') : 'Any',
              description: tag.text.to_s
            }
          end
        }
      end
      
      @mcp_methods.each do |method_name, method_info|
        method_info[:method_obj] = Object.method(method_name.to_sym)
      end
    end

    def start_interactive
      $stdin.each_line do |line|
        line = line.strip
        next if line.empty?
        
        begin
          request = JSON.parse(line)
          response = handle_request(request)
          $stdout.puts response.to_json
          $stdout.flush
        rescue JSON::ParserError => e
          $stdout.puts({
            jsonrpc: "2.0",
            error: { code: -32700, message: "Parse error: #{e.message}" },
            id: nil
          }.to_json)
          $stdout.flush
        end
      end
    end

    def handle_request(request)
      method = request["method"]
      id = request["id"]

      case method
      when "initialize"
        handle_initialize(id)
      when "tools/list"
        handle_tools_list(id)
      when "tools/call"
        handle_tools_call(id, request["params"] || {})
      else
        { jsonrpc: "2.0", error: { code: -32601, message: "Method not found" }, id: id }
      end
    end

    def handle_initialize(id)
      {
        jsonrpc: "2.0",
        result: {
          protocolVersion: "2024-11-05",
          capabilities: { tools: {} },
          serverInfo: { name: "schnellmcp", version: "0.1.0" }
        },
        id: id
      }
    end

    def handle_tools_list(id)
      {
        jsonrpc: "2.0",
        result: {
          tools: @mcp_methods.map do |name, method_info|
            {
              name: name,
              description: method_info[:description],
              inputSchema: {
                type: "object",
                properties: method_info[:parameters].each_with_object({}) do |param, hash|
                  hash[param[:name]] = { type: map_type_to_schema(param[:type]), description: param[:description] }
                end,
                required: method_info[:parameters].map { |param| param[:name] }
              }
            }
          end
        },
        id: id
      }
    end

    def handle_tools_call(id, params)
      tool_name = params["name"]
      method_info = @mcp_methods[tool_name]

      return { jsonrpc: "2.0", error: { code: -32602, message: "Tool not found" }, id: id } unless method_info

      begin
        args = method_info[:parameters].map do |param|
          value = (params["arguments"] || {})[param[:name]]
          coerce_type(value, param[:type])
        end
        result = method_info[:method_obj].call(*args)

        {
          jsonrpc: "2.0",
          result: { content: [{ type: "text", text: result.to_s }] },
          id: id
        }
      rescue => e
        {
          jsonrpc: "2.0",
          error: {
            code: -32603,
            message: "Execution error: #{e.message}",
            data: { backtrace: e.backtrace.first(5) }
          },
          id: id
        }
      end
    end

    def coerce_type(value, type)
      return value if value.nil?

      case type.to_s.downcase
      when /integer/
        value.to_i
      when /float/, /numeric/
        value.to_f
      when /boolean/, /trueclass/, /falseclass/
        value.to_s.downcase == 'true'
      when /array/
        value.is_a?(Array) ? value : [value]
      else
        value.to_s
      end
    end

    def map_type_to_schema(type)
      case type.to_s.downcase
      when /integer/
        "integer"
      when /float/, /numeric/
        "number"
      when /boolean/, /trueclass/, /falseclass/
        "boolean"
      when /array/
        "array"
      when /hash/
        "object"
      else
        "string"
      end
    end
  end
end
