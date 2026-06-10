#!/usr/bin/env node
// Patch signoz-mcp-server v1.2.x to work with SigNoz v0.127.x
// - searchLogsV3: /api/v3/logs → /api/v3/query_range + ms→ns timestamps
// - index.js: parse query_range response structure instead of logs response

const fs = require('fs');

const BASE = '/usr/local/lib/node_modules/signoz-mcp-server/dist';

// ── Patch client.js ──────────────────────────────────────────────────────────
let client = fs.readFileSync(`${BASE}/client.js`, 'utf8');

// Change URL and convert timestamps ms→ns, add step/variables
client = client.replace(
  `return this.request({
            method: 'POST',
            url: '/api/v3/logs',
            data: {
                start: params.start,
                end: params.end,
                compositeQuery,
            },
        });`,
  `return this.request({
            method: 'POST',
            url: '/api/v3/query_range',
            data: {
                start: Math.round(params.start * 1000000),
                end: Math.round(params.end * 1000000),
                step: 60,
                compositeQuery,
                variables: {},
            },
        });`
);

// Fix filter item key: must be AttributeKey object, not string
client = client.replace(
  /(\s*)\{\s*\n(\s*)key: 'body',\s*\n(\s*)op: 'contains',/,
  (_, indent, keyIndent, opIndent) =>
    `${indent}{\n${keyIndent}key: { key: 'body', dataType: 'string', type: '', isColumn: true, isJSON: false },\n${opIndent}op: 'contains',`
);

fs.writeFileSync(`${BASE}/client.js`, client);
console.log('✓ client.js patched');

// ── Patch index.js ───────────────────────────────────────────────────────────
let index = fs.readFileSync(`${BASE}/index.js`, 'utf8');

// Fix result parsing: client.request() strips outer data envelope,
// query_range returns {resultType, result:[{timestamp, list:[{timestamp, data:{body,...}}]}]}
index = index.replace(
  'const logs = result.logs || [];\n                    const total = result.total || 0;',
  `const _qList = (result.result && result.result[0] && result.result[0].list) || [];
                    const logs = _qList.map(item => ({ ...(item.data || item), timestamp: item.timestamp || (item.data||{}).timestamp }));
                    const total = _qList.length || (result.total || 0);`
);
// Fix timestamp display: query_range returns ISO strings, old API returned nanosecond ints
index = index.replace(
  "logs.slice(0, 20).map((log) => `[${new Date(parseInt(log.timestamp) / 1000000).toISOString()}] ${log.body || log.message || JSON.stringify(log)}`).join('\\n')",
  "logs.slice(0, 20).map((log) => { let ts; try { ts = isNaN(log.timestamp) ? new Date(log.timestamp).toISOString() : new Date(parseInt(log.timestamp) / 1000000).toISOString(); } catch(e) { ts = String(log.timestamp||'?'); } return `[${ts}] ${log.body || log.message || JSON.stringify(log)}`; }).join('\\n')"
);

fs.writeFileSync(`${BASE}/index.js`, index);
console.log('✓ index.js patched');
console.log('Patch complete');
