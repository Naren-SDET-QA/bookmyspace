import { McpAdapter, type McpTransport } from './mcp_adapter.ts';

class FakeTransport implements McpTransport {
  calls: Array<Record<string, unknown>> = [];
  async send(message: Record<string, unknown>): Promise<Record<string, unknown>> {
    this.calls.push(message);
    if (message.method === 'initialize') return { jsonrpc: '2.0', id: message.id, result: { capabilities: { tools: {} } } };
    if (message.method === 'tools/list') return { jsonrpc: '2.0', id: message.id, result: { tools: [{ name: 'search', inputSchema: { type: 'object' } }] } };
    return { jsonrpc: '2.0', id: message.id, result: { content: [{ type: 'text', text: 'ok' }] } };
  }
}

Deno.test('initializes and discovers MCP tools through the protocol', async () => {
  const transport = new FakeTransport();
  const adapter = new McpAdapter(transport);
  const tools = await adapter.listTools();
  if (tools.length !== 1 || tools[0].name !== 'search') throw new Error('tool discovery failed');
  if (transport.calls[0].method !== 'initialize' || transport.calls[2].method !== 'tools/list') throw new Error('invalid MCP handshake');
});

Deno.test('calls configured MCP tools without provider-specific parameters', async () => {
  const adapter = new McpAdapter(new FakeTransport());
  const result = await adapter.callTool('search', { location: 'Hyderabad' });
  const content = result.content as Array<Record<string, unknown>> | undefined;
  if (content?.[0]?.text !== 'ok') throw new Error('tool call failed');
});

Deno.test('rejects MCP protocol errors', async () => {
  const transport: McpTransport = { send: async () => ({ jsonrpc: '2.0', id: 1, error: { code: -32602, message: 'invalid params' } }) };
  let rejected = false;
  try { await new McpAdapter(transport).callTool('search', {}); } catch (error) { rejected = String(error).includes('invalid params'); }
  if (!rejected) throw new Error('MCP error was not surfaced safely');
});
