#!/usr/bin/env python3
# Write sources.json: pins, licences and host compile configurations.
# Usage: gen_sources.py SRC_DIR PINS_JSON > sources.json
# PINS_JSON holds the values measured at fetch time (commits, sha256, dates).
import json, sys, pathlib, re

src = pathlib.Path(sys.argv[1])
pins = json.loads(pathlib.Path(sys.argv[2]).read_text())

grammars = []
for f in sorted(src.glob('vscode/extensions/*/syntaxes/*.tmLanguage.json')):
    ext = f.parent.parent
    g = json.loads(f.read_text(encoding='utf-8'))
    info = g.get('information_for_contributors') or []
    info = ' '.join(info) if isinstance(info, list) else str(info)
    ver = g.get('version', '')
    regs = []
    man = ext / 'cgmanifest.json'
    if man.exists():
        for r in json.loads(man.read_text(encoding='utf-8')).get('registrations', []):
            git = r.get('component', {}).get('git', {})
            regs.append({'repository': git.get('repositoryUrl'), 'commit': git.get('commitHash'),
                         'license': r.get('license'), 'version': r.get('version')})
    hay = info + ' ' + ver
    match = [r for r in regs if r['repository'] and r['repository'].rstrip('/').split('github.com/')[-1].lower() in hay.lower()]
    grammars.append({
        'file': f.relative_to(src / 'vscode').as_posix(),
        'upstream': match[0] if len(match) == 1 else None,
        'cgmanifest_registrations': regs if len(match) != 1 else None,
        'converted_from': re.findall(r'https?://\S+', info)[:1] or None,
        'note': None if man.exists() else 'no cgmanifest.json: grammar authored in microsoft/vscode (MIT)',
    })

out = {
    'retrieved': pins['retrieved'],
    'oniguruma': {'repository': 'https://github.com/kkos/oniguruma', 'commit': pins['oniguruma'],
                  'license': 'BSD-2-Clause',
                  'note': 'instrument.patch and classify.c derive from / use Oniguruma internals; '
                          'Copyright (c) 2002-2021 K.Kosako, BSD-2-Clause conditions retained in instrument.patch'},
    'sources': {
        'vscode': {'repository': 'https://github.com/microsoft/vscode', 'commit': pins['vscode'],
                   'license': 'MIT', 'checkout': 'sparse, extensions/ only, depth 1',
                   'grammar_count': len(grammars)},
        'vscode-textmate': {'repository': 'https://github.com/microsoft/vscode-textmate',
                            'commit': pins['vscode-textmate'], 'license': 'MIT',
                            'npm': 'vscode-textmate@9.3.2 (version at that commit; VS Code package.json requires ^9.3.2)'},
        'vscode-oniguruma': {'repository': 'https://github.com/microsoft/vscode-oniguruma',
                             'commit': pins['vscode-oniguruma'], 'license': 'MIT',
                             'bundled_oniguruma': 'deps/oniguruma submodule at 08d3611 (v6.9.8), not f95747b',
                             'npm': 'vscode-oniguruma@1.7.0: the version VS Code pins in package.json; the '
                                    'repository HEAD says 2.1.0 but 2.1.0 is not published on npm (latest 2.0.1)'},
        'jq': {'repository': 'https://github.com/jqlang/jq', 'tag': 'jq-1.8.2', 'commit': pins['jq'],
               'tarball': 'https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-1.8.2.tar.gz',
               'sha256': pins['jq_sha256'], 'license': 'MIT (code); manual CC-BY-3.0',
               'corpus': ['tests/jq.test', 'tests/onig.test', 'tests/optional.test',
                          'docs/content/manual/manual.yml']},
        'php-src': {'repository': 'https://github.com/php/php-src', 'tag': 'php-8.5.12', 'commit': pins['php'],
                    'tarball': 'https://www.php.net/distributions/php-8.5.12.tar.xz',
                    'sha256': pins['php_sha256'], 'license': 'PHP-3.01',
                    'corpus': ['ext/mbstring/tests/*.phpt']},
        'php-doc-en': {'repository': 'https://github.com/php/doc-en', 'commit': pins['doc-en'],
                       'license': 'CC-BY-3.0', 'checkout': 'sparse, reference/mbstring only, depth 1',
                       'corpus': ['reference/mbstring/**/*.xml <programlisting role="php">']},
    },
    'host_configurations': {
        'vscode': {
            'encoding': 'UTF-8', 'syntax': 'ONIGURUMA (ONIG_SYNTAX_DEFAULT)', 'options': ['CAPTURE_GROUP'],
            'evidence': [
                'vscode-oniguruma src/onig.cc createOnigRegExp: onig_new(..., options, ONIG_ENCODING_UTF8, syntax, ...)',
                'vscode-oniguruma src/index.ts OnigScanner: options default [FindOption.CaptureGroup], syntax default Syntax.Default',
                'vscode-oniguruma src/onig.cc findNextOnigScannerMatch: onig_regset_search with ONIG_REGSET_POSITION_LEAD when strLength < 1000, else per-regex onig_search',
                'vscode-textmate src/rule.ts RegExpSource: \\z rewritten to $(?!\\n)(?<!\\n); \\A and \\G replaced by U+FFFF in the scanner variants where they cannot match',
                'vscode-textmate src/debug.ts UseOnigurumaFindOptions = false: search-time FindOption is None; \\A/\\G handled by the rewrite above',
                'vscode-textmate src/rule.ts resolveBackReferences: \\N in end/while replaced by the escaped begin capture text',
            ]},
        'jq': {
            'encoding': 'UTF-8', 'syntax': 'PERL_NG', 'options': ['CAPTURE_GROUP'],
            'flags': {'i': 'IGNORECASE', 'x': 'EXTEND', 'm': 'MULTILINE', 's': 'SINGLELINE',
                      'p': 'MULTILINE|SINGLELINE', 'l': 'FIND_LONGEST', 'n': 'FIND_NOT_EMPTY', 'g': '(global search, no option)'},
            'evidence': ['jq src/builtin.c f_match: onig_new(..., options, ONIG_ENCODING_UTF8, ONIG_SYNTAX_PERL_NG, ...); onig_search(..., ONIG_OPTION_NONE)']},
        'php': {
            'encoding': 'mb_regex_encoding(), default UTF-8 (or mbstring.internal_encoding)',
            'syntax': 'RUBY by default; option letters j u g c r z b d select JAVA GNU_REGEX GREP EMACS RUBY PERL POSIX_BASIC POSIX_EXTENDED',
            'options': ['MULTILINE', 'SINGLELINE'],
            'notes': [
                'an explicit option string replaces the default options (it is not OR-ed with MULTILINE|SINGLELINE)',
                'mb_eregi / mb_eregi_replace add IGNORECASE',
                'mb_regex_set_options() replaces the default options and syntax',
                'searches use onig_search_with_param with match stack limit mbstring.regex_stack_limit (default 100000; upstream default 0 = unlimited) and retry limit mbstring.regex_retry_limit (default 1000000; upstream default 10000000)',
            ],
            'evidence': ['php-src ext/mbstring/php_mbregex.c: _php_mb_regex_globals_alloc, _php_mb_regex_init_options, php_mbregex_compile_pattern, _php_mb_onig_search',
                         'php-src ext/mbstring/mbstring.c: INI entries mbstring.regex_stack_limit, mbstring.regex_retry_limit']},
    },
    'grammars': grammars,
}
json.dump(out, sys.stdout, indent=1, ensure_ascii=False)
print()
