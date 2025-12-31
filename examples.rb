require_relative 'schnellmcp'

# Add two numbers
#
# @param a [Integer] First number
# @param b [Integer] Second number
#
# @return [Integer] Sum of a and b
#
# @mcp.tool
def add(a, b)
  a + b
end

# Compile Ruby code to bytecode instructions
#
# @param code [String] Ruby code to compile
# @return [String] Disassembled bytecode instructions
#
# @mcp.tool
def compile_to_bytecode(code)
  iseq = RubyVM::InstructionSequence.compile(code)
  iseq.disasm
rescue SyntaxError => e
  "Syntax Error: #{e.message}"
end

# Start the MCP server if called directly
SchnellMCP::Server.run(__FILE__) if __FILE__ == $0
