require 'minitest/autorun'
require_relative 'schnellmcp'
require_relative 'examples'

class TestSchnellMCP < Minitest::Test
  def setup
    @server = SchnellMCP::Server.new('examples.rb', interactive: false)
  end

  def test_initialize_request
    request = {
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "initialize",
      "params" => {
        "protocolVersion" => "2024-11-05",
        "capabilities" => {},
        "clientInfo" => {
          "name" => "test-client",
          "version" => "1.0.0"
        }
      }
    }

    response = @server.send_request(request)

    assert_equal "2.0", response[:jsonrpc]
    assert_equal 1, response[:id]
    assert response[:result]
    assert_equal "2024-11-05", response[:result][:protocolVersion]
    assert response[:result][:capabilities]
    assert response[:result][:serverInfo]
    assert_equal "schnellmcp", response[:result][:serverInfo][:name]
  end

  def test_tools_list
    request = {
      "jsonrpc" => "2.0",
      "id" => 2,
      "method" => "tools/list"
    }

    response = @server.send_request(request)

    assert_equal "2.0", response[:jsonrpc]
    assert_equal 2, response[:id]
    assert response[:result]
    assert response[:result][:tools]
    assert response[:result][:tools].is_a?(Array)
    
    tool_names = response[:result][:tools].map { |t| t[:name] }
    assert_includes tool_names, "add"
    assert_includes tool_names, "compile_to_bytecode"
    assert_equal 2, tool_names.length

    add_tool = response[:result][:tools].find { |t| t[:name] == "add" }
    assert_equal "integer", add_tool[:inputSchema][:properties]["a"][:type]
    assert_equal "integer", add_tool[:inputSchema][:properties]["b"][:type]

    compile_tool = response[:result][:tools].find { |t| t[:name] == "compile_to_bytecode" }
    assert compile_tool[:description]
    assert compile_tool[:inputSchema]
    assert_equal "object", compile_tool[:inputSchema][:type]
    assert compile_tool[:inputSchema][:properties]
    assert_includes compile_tool[:inputSchema][:properties].keys, "code"
    assert_equal "string", compile_tool[:inputSchema][:properties]["code"][:type]
  end

  def test_compile_to_bytecode
    request = {
      "jsonrpc" => "2.0",
      "id" => 3,
      "method" => "tools/call",
      "params" => {
        "name" => "compile_to_bytecode",
        "arguments" => {
          "code" => "puts 'hello'"
        }
      }
    }

    response = @server.send_request(request)

    assert_equal "2.0", response[:jsonrpc]
    assert_equal 3, response[:id]
    assert response[:result]
    assert response[:result][:content]
    assert_equal 1, response[:result][:content].length
    assert_equal "text", response[:result][:content][0][:type]
    text = response[:result][:content][0][:text]
    # Check for bytecode structure (instruction names may vary by Ruby version)
    assert_includes text, "disasm"
    assert_includes text, "puts"
  end

  def test_add_with_integer_coercion
    request = {
      "jsonrpc" => "2.0",
      "id" => 4,
      "method" => "tools/call",
      "params" => {
        "name" => "add",
        "arguments" => {
          "a" => "5",
          "b" => "20"
        }
      }
    }

    response = @server.send_request(request)

    assert_equal "2.0", response[:jsonrpc]
    assert response[:result]
    text = response[:result][:content][0][:text]
    assert_equal "25", text
  end

  def test_unknown_method
    request = {
      "jsonrpc" => "2.0",
      "id" => 5,
      "method" => "unknown/method"
    }

    response = @server.send_request(request)

    assert_equal "2.0", response[:jsonrpc]
    assert response[:error]
    assert_equal(-32601, response[:error][:code])
  end

  def test_unknown_tool
    request = {
      "jsonrpc" => "2.0",
      "id" => 6,
      "method" => "tools/call",
      "params" => {
        "name" => "nonexistent",
        "arguments" => {}
      }
    }

    response = @server.send_request(request)

    assert response[:error]
    assert_equal(-32602, response[:error][:code])
  end
end
