// Frequency profile of the VS Code scanner searches (experiment #1,
// follow-up for #11; added after #11 started).  Same replay as
// replay_vscode.js (same fixtures, same order, same scanner ids), but instead
// of logging each distinct search once it counts how many times
// vscode-textmate issues it.
// Usage: node freq_vscode.js VSCODE_CHECKOUT NODE_MODULES_DIR OUT.jsonl
// Output lines, in first-seen order (the order of replay_vscode.js's log):
//   {"scanner":n,"start":p,"options":o,"subject_sha1":h,"subject_bytes":b,"count":c}
// with p a UTF-8 byte offset and h the SHA-1 of the UTF-8 subject; then one
// {"t":"stats",...} line.
'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const [vscodeDir, nodeModules, outFile] = process.argv.slice(2);
const vsctm = require(path.join(nodeModules, 'vscode-textmate'));
const oniguruma = require(path.join(nodeModules, 'vscode-oniguruma'));

const ext = path.join(vscodeDir, 'extensions');
const grammars = {}, langToScope = {}, extToLang = {}, nameToLang = {}, injections = {};
for (const d of fs.readdirSync(ext)) {
  const pj = path.join(ext, d, 'package.json');
  if (!fs.existsSync(pj)) continue;
  const c = JSON.parse(fs.readFileSync(pj, 'utf8')).contributes || {};
  for (const l of c.languages || []) {
    for (const e of l.extensions || []) extToLang[e.toLowerCase()] = extToLang[e.toLowerCase()] || l.id;
    for (const f of l.filenames || []) nameToLang[f] = nameToLang[f] || l.id;
  }
  for (const g of c.grammars || []) {
    const file = path.join(ext, d, g.path);
    if (!fs.existsSync(file)) continue;
    grammars[g.scopeName] = file;
    if (g.language && !langToScope[g.language]) langToScope[g.language] = g.scopeName;
    for (const t of g.injectTo || []) (injections[t] = injections[t] || []).push(g.scopeName);
  }
}

const out = fs.openSync(outFile, 'w');
const emit = (o) => fs.writeSync(out, JSON.stringify(o) + '\n');
let current = { file: null, line: 0 };
let nScanners = 0;
const seen = new Map();  // key -> record (insertion order = first seen)
let calls = 0;
const u8 = (s, i) => Buffer.byteLength(s.substring(0, i), 'utf8');

const wasm = fs.readFileSync(path.join(nodeModules, 'vscode-oniguruma/release/onig.wasm')).buffer;
const onigLib = oniguruma.loadWASM(wasm).then(() => ({
  createOnigScanner(patterns) {
    const real = new oniguruma.OnigScanner(patterns);
    const id = nScanners++;
    return {
      findNextMatchSync(string, startPosition, options) {
        const r = real.findNextMatchSync(string, startPosition, options);
        const s = typeof string === 'string' ? string : string.content;
        const key = id + '\u0000' + startPosition + '\u0000' + (options | 0) + '\u0000' + s;
        calls++;
        const rec = seen.get(key);
        if (rec) rec.count++;
        else seen.set(key, { scanner: id, start: u8(s, startPosition), options: options | 0,
                             subject_sha1: crypto.createHash('sha1').update(s, 'utf8').digest('hex'),
                             subject_bytes: Buffer.byteLength(s, 'utf8'), count: 1 });
        return r;
      },
      dispose() { real.dispose(); },
    };
  },
  createOnigString(s) { return new oniguruma.OnigString(s); },
}));

const registry = new vsctm.Registry({
  onigLib,
  loadGrammar: async (scopeName) => {
    const f = grammars[scopeName];
    if (!f) return null;
    return vsctm.parseRawGrammar(fs.readFileSync(f, 'utf8'), f);
  },
  getInjections: (scopeName) => injections[scopeName] || [],
});

(async () => {
  const dirs = ['vscode-colorize-tests', 'vscode-colorize-perf-tests'].map(d => path.join(ext, d, 'test/colorize-fixtures'));
  const stats = { files: 0, skipped: [], lines: 0 };
  for (const dir of dirs) {
    for (const f of fs.readdirSync(dir).sort()) {
      const base = path.basename(f);
      const lang = nameToLang[base] || extToLang[path.extname(f).toLowerCase()];
      const scope = lang && langToScope[lang];
      if (!scope) { stats.skipped.push(f); continue; }
      const g = await registry.loadGrammar(scope);
      if (!g) { stats.skipped.push(f); continue; }
      const rel = path.relative(vscodeDir, path.join(dir, f));
      const text = fs.readFileSync(path.join(dir, f), 'utf8');
      let state = vsctm.INITIAL;
      const lines = text.split(/\r\n|\r|\n/);
      for (let i = 0; i < lines.length; i++) {
        current = { file: rel, line: i + 1 };
        state = g.tokenizeLine(lines[i], state).ruleStack;
        stats.lines++;
      }
      stats.files++;
    }
  }
  for (const rec of seen.values()) emit(rec);
  stats.scanners = nScanners; stats.searches = seen.size; stats.calls = calls;
  emit({ t: 'stats', ...stats });
  fs.closeSync(out);
  console.log(JSON.stringify({ ...stats, skipped: stats.skipped.length }));
})();
