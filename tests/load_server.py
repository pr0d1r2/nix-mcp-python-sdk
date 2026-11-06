"""Build an MCP server with a tool and list it through an in-memory client session.

pythonImportsCheck only proves the modules import. This drives the protocol
round trip semble relies on: register a tool, initialize a session, list tools.
"""

import sys

import anyio
from mcp.client.client import Client
from mcp.server.mcpserver import MCPServer


async def run() -> int:
    server = MCPServer("check")

    @server.tool()
    def add(a: int, b: int) -> int:
        """Add two integers."""
        return a + b

    async with Client(server) as client:
        tools = await client.list_tools()
        names = [tool.name for tool in tools.tools]
        if names != ["add"]:
            print(f"unexpected tools: {names}", file=sys.stderr)
            return 1
        result = await client.call_tool("add", {"a": 2, "b": 3})
        print(f"tools: {names}; add(2, 3) -> {result.content[0].text}")
    return 0


if __name__ == "__main__":
    sys.exit(anyio.run(run))
