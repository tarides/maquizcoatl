// Tokenise VS Code's colorize fixtures with vscode-textmate + vscode-oniguruma
// and log every scanner search (dynamic capture for experiment #1).
// Usage: node replay_vscode.js VSCODE_CHECKOUT NODE_MODULES_DIR OUT.jsonl
// Output lines: {"t":"scanner","id":n,"patterns":[...]} once per scanner,
// then {"t":"search","scanner":n,"file":f,"line":l,"subject":s,"start":p,
//        "options":o,"index":i,"match":[from,to]} with UTF-8 byte offsets.
'use strict';
const fs = require('fs');
const path = require('path');
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
const seen = new Set();
const u8 = (s, i) => Buffer.byteLength(s.substring(0, i), 'utf8');

const wasm = fs.readFileSync(path.join(nodeModules, 'vscode-oniguruma/release/onig.wasm')).buffer;
const onigLib = oniguruma.loadWASM(wasm).then(() => ({
  createOnigScanner(patterns) {
    const real = new oniguruma.OnigScanner(patterns);
    const id = nScanners++;
    emit({ t: 'scanner', id, patterns });
    return {
      findNextMatchSync(string, startPosition, options) {
        const r = real.findNextMatchSync(string, startPosition, options);
        const s = typeof string === 'string' ? string : string.content;
        const key = id + '\u0000' + startPosition + '\u0000' + (options | 0) + '\u0000' + s;
        if (!seen.has(key)) {
          seen.add(key);
          emit({ t: 'search', scanner: id, file: current.file, line: current.line,
                 subject: s, start: u8(s, startPosition), options: options | 0,
                 index: r ? r.index : -1,
                 match: r ? [u8(s, r.captureIndices[0].start), u8(s, r.captureIndices[0].end)] : null });
        }
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
  stats.scanners = nScanners; stats.searches = seen.size;
  emit({ t: 'stats', ...stats });
  fs.closeSync(out);
  console.log(JSON.stringify(stats));
})();
