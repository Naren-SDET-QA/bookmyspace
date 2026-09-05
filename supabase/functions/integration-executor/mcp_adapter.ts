import { isAllowedDestination } from './executor_policy.ts';

export type McpMessage = Record<string, unknown>;

export interface McpTransport {
  send(message: McpMessage): Promise<McpMessage>;
}

export interface McpTool {
  name: string;
  description?: string;
  inputSchema?: Record<string, unknown>;
}

export class McpAdapter {
  private nextId = 1;
  private initialized = false;

  constructor(private readonly transport: McpTransport) {}

  private async request(method: string, params: Record<string, unknown> = {}): Promise<McpMessage> {
    const response = await this.transport.send({ jsonrpc: '2.0', id: this.nextId++, method, params });
    if (response.error) throw new Error(String((response.error as Record<string, unknown>).message ?? 'mcp_error'));
    return (response.result as McpMessage | undefined) ?? {};
  }

  async initialize(protocolVersion = '2024-11-05'): Promise<McpMessage> {
    const result = await this.request('initialize', {
      protocolVersion,
      capabilities: {},
      clientInfo: { name: 'bookmyspace-integration-executor', version: '1.0' },
    });
    await this.transport.send({ jsonrpc: '2.0', method: 'notifications/initialized', params: {} });
    this.initialized = true;
    return result;
  }

  async listTools(): Promise<McpTool[]> {
    if (!this.initialized) await this.initialize();
    const result = await this.request('tools/list');
    return Array.isArray(result.tools) ? result.tools as McpTool[] : [];
  }

  async callTool(name: string, arguments_: Record<string, unknown>): Promise<McpMessage> {
    if (!this.initialized) await this.initialize();
    return this.request('tools/call', { name, arguments: arguments_ });
  }
}

export class HttpMcpTransport implements McpTransport {
  constructor(
    private readonly endpoint: string,
    private readonly headers: Headers,
    private readonly timeoutMs = 10000,
  ) {
    if (!isAllowedDestination(endpoint)) throw new Error('destination_not_allowed');
  }

  async send(message: McpMessage): Promise<McpMessage> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), Math.min(Math.max(this.timeoutMs, 100), 120000));
    try {
      const response = await fetch(this.endpoint, {
        method: 'POST',
        headers: this.headers,
        body: JSON.stringify(message),
        signal: controller.signal,
      });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(`mcp_http_${response.status}`);
      return payload as McpMessage;
    } finally {
      clearTimeout(timer);
    }
  }
}
