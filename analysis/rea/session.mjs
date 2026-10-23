// 在同一 REA MCP 会话中连续查询，避免每个 CLI 命令重复导入二进制。
// 输入：每行 {"name":"工具名","arguments":{},"save":"结果文件名"}。
import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import { writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const outputDirectory = dirname(fileURLToPath(import.meta.url));
const child = spawn('rea', ['mcp'], { stdio: ['pipe', 'pipe', 'pipe'] });
process.on('SIGINT', () => { child.kill('SIGTERM'); });
process.on('SIGTERM', () => { child.kill('SIGTERM'); });
child.on('exit', code => { process.exit(code ?? 0); });
let nextID = 0;
const pending = new Map();
child.stderr.on('data', chunk => process.stderr.write(chunk));
const responses = createInterface({ input: child.stdout });
responses.on('line', line => {
  try {
    const result = JSON.parse(line);
    if (result.id !== undefined && pending.has(result.id)) {
      pending.get(result.id)(result);
      pending.delete(result.id);
    }
  } catch { process.stderr.write(line + '\n'); }
});
const request = (method, params) => new Promise(resolveRequest => {
  const id = ++nextID;
  pending.set(id, resolveRequest);
  child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
});
const persist = (name, value) => {
  if (!/^[a-zA-Z0-9_-]+$/.test(name)) throw new Error('无效结果文件名');
  writeFileSync(resolve(outputDirectory, name + '.json'), JSON.stringify(value, null, 2) + '\n');
};
const initialized = await request('initialize', {
  protocolVersion: '2024-11-05', capabilities: {},
  clientInfo: { name: 'xpastepal-local-analysis', version: '1.0' }
});
persist('mcp-initialize', initialized);
child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n');
const catalog = await request('tools/list', {});
persist('mcp-tools', catalog);
console.log(JSON.stringify({ ready: true, toolCount: catalog.result?.tools?.length }));
const input = createInterface({ input: process.stdin });
for await (const line of input) {
  if (!line.trim()) continue;
  const command = JSON.parse(line);
  if (command.exit) { child.stdin.end(); child.kill('SIGTERM'); break; }
  console.log(JSON.stringify({ running: command.name, save: command.save }));
  const result = await request('tools/call', { name: command.name, arguments: command.arguments ?? {} });
  persist(command.save, result);
  console.log(JSON.stringify({ saved: command.save + '.json', error: result.error ?? null, isError: result.result?.isError ?? false, bytes: JSON.stringify(result).length }));
}
