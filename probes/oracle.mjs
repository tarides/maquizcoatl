// oracle.mjs: JavaScript (ECMA-262, as implemented by V8) oracle for the
// semantic probes of experiment #2.
//
// Usage: node --js-regexp-modifiers --js-regexp-duplicate-named-groups \
//          probes/oracle.mjs FILE.tsv
//
// Reads the same probe data file as harness.c and prints, per probe, the
// JavaScript result without and with the `u` flag (the `d` flag is always
// on, for capture indices). Offsets are in code points, as in the
// harness's `result` column.
//
// The `js` column of a probe:
//   empty         -> the Oniguruma pattern verbatim, flag `i` if the probe
//                    options contain IGNORECASE;
//   /src/flags    -> that JavaScript spelling;
//   n/a ...       -> inexpressible in ECMA-262 (clause cited); not run.
import { readFileSync } from "node:fs";

const file = process.argv[2];
const lines = readFileSync(file, "utf8").split("\n");

function decodeSubject(s) {
  let out = "";
  for (let i = 0; i < s.length; ) {
    if (s[i] === "\\" && s[i + 1] === "x" && /^[0-9a-fA-F]{2}$/.test(s.slice(i + 2, i + 4))) {
      out += String.fromCodePoint(parseInt(s.slice(i + 2, i + 4), 16));
      i += 4;
    } else if (s[i] === "\\" && s[i + 1] === "u" && s[i + 2] === "{") {
      const j = s.indexOf("}", i);
      out += String.fromCodePoint(parseInt(s.slice(i + 3, j), 16));
      i = j + 1;
    } else if (s[i] === "\\" && s[i + 1] === "\\") { out += "\\"; i += 2; }
    else if (s[i] === "\\" && s[i + 1] === "t") { out += "\t"; i += 2; }
    else if (s[i] === "\\" && s[i + 1] === "n") { out += "\n"; i += 2; }
    else { const cp = s.codePointAt(i); out += String.fromCodePoint(cp); i += cp > 0xffff ? 2 : 1; }
  }
  return out;
}

// UTF-16 index -> code point index.
const cpOff = (str, i) => [...str.slice(0, i)].length;

function run(src, flags, subj) {
  let re;
  try { re = new RegExp(src, flags); }
  catch (e) { return `E ${e.name}: ${e.message.replace(/\t/g, " ")}`; }
  const m = re.exec(subj);
  if (!m) return "N";
  const parts = m.indices.map(([b, e] = [], k) =>
    (k === 0 ? "M " : (k === 1 ? " | " : " ") + `${k}=`) +
    (b === undefined ? "-" : `${cpOff(subj, b)}-${cpOff(subj, e)}`));
  return parts.join("");
}

function jsSpelling(pat, opts, js) {
  if (js && js.startsWith("n/a")) return null;
  if (js && js.startsWith("/")) {
    const k = js.lastIndexOf("/");
    return { src: js.slice(1, k), flags: js.slice(k + 1), translated: true };
  }
  return { src: pat, flags: opts.split(",").includes("IGNORECASE") ? "i" : "", translated: false };
}

function marks(sp, enc) {
  const m = [];
  if (sp.translated) m.push("translated");
  if (/\(\?([ims]+(-[ims]+)?|-[ims]+):/.test(sp.src)) m.push("js-flagged");
  const names = [...sp.src.matchAll(/\(\?<([A-Za-z_]\w*)>/g)].map(x => x[1]);
  if (new Set(names).size !== names.length) { if (!m.includes("js-flagged")) m.push("js-flagged"); }
  if (enc === "ISO-8859-1") m.push("js-on-codepoints");
  return m.join(",") || "-";
}

console.log(["id", "js_pattern", "js_flags", "js_marks", "js_result", "js_result_u"].join("\t"));
for (const line of lines) {
  if (!line || line.startsWith("#")) continue;
  const f = line.split("\t");
  if (f[0] === "id") continue;
  const [id, , enc, opts, pat, subj, js = ""] = f;
  const sp = jsSpelling(pat, opts, js);
  if (!sp) { console.log([id, js, "-", "n/a", "n/a", "n/a"].join("\t")); continue; }
  const s = decodeSubject(subj);
  const flags = sp.flags.replace(/[du]/g, "");
  console.log([id, sp.src, flags || "-", marks(sp, enc),
               run(sp.src, flags + "d", s), run(sp.src, flags + "du", s)].join("\t"));
}
