// compare.mjs: join the Debug harness, ASan/UBSan harness and JavaScript
// oracle outputs of one probe file on probe id.
//
// Usage: node probes/compare.mjs DEBUG.tsv ASAN.tsv ASAN.stderr JS.tsv
//
// Output columns: id, syntax, encoding, options, pattern, subject,
// onig (Debug result, code-point offsets), asan_same (Debug == ASan),
// sanitizer (reports attributed to the probe, or "clean"), js_pattern,
// js_flags, js_marks, js (with `u`), js_nou (without `u`), cmp.
//
// cmp: "same" when the Oniguruma result equals the JavaScript `u`-mode
// result (two compile errors count as same), "different" otherwise,
// "n/a" when the probe is inexpressible in ECMA-262.
import { readFileSync } from "node:fs";

const [dbgF, asanF, asanErrF, jsF] = process.argv.slice(2);
const tsv = f => {
  const [h, ...rows] = readFileSync(f, "utf8").split("\n").filter(Boolean);
  const cols = h.split("\t");
  return rows.map(r => Object.fromEntries(r.split("\t").map((v, i) => [cols[i], v])));
};
const dbg = tsv(dbgF);
const asan = new Map(tsv(asanF).map(r => [r.id, r]));
const js = new Map(tsv(jsF).map(r => [r.id, r]));

// Attribute sanitizer report lines to the probe whose marker precedes them.
const san = new Map();
let cur = "<start>";
for (const l of readFileSync(asanErrF, "utf8").split("\n")) {
  const m = /^@@probe (.*)$/.exec(l);
  if (m) { cur = m[1]; continue; }
  if (/runtime error:|ERROR: AddressSanitizer|ERROR: LeakSanitizer|SUMMARY: (Address|Undefined|Leak)Sanitizer/.test(l))
    san.set(cur, (san.has(cur) ? san.get(cur) + " ; " : "") + l.trim().replace(/\t/g, " ").replace(/\/\S*\/(src|probes)\//g, "$1/"));
}

const cls = r => r.startsWith("E ") ? "E" : r;
console.log(["id", "syntax", "encoding", "options", "pattern", "subject", "onig",
             "asan_same", "sanitizer", "js_pattern", "js_flags", "js_marks", "js",
             "js_nou", "cmp"].join("\t"));
for (const d of dbg) {
  const a = asan.get(d.id), j = js.get(d.id);
  const cmp = j.js_result_u === "n/a" ? "n/a"
            : cls(d.result) === cls(j.js_result_u) ? "same" : "different";
  console.log([d.id, d.syntax, d.encoding, d.options, d.pattern, d.subject, d.result,
               a && a.result === d.result ? "yes" : "NO",
               san.get(d.id) || "clean", j.js_pattern, j.js_flags, j.js_marks,
               j.js_result_u, j.js_result, cmp].join("\t"));
}
for (const k of ["<start>", "<exit>"]) if (san.has(k)) console.error(`sanitizer ${k}: ${san.get(k)}`);
