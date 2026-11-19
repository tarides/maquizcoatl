/* replay.c -- compute expected results of VS Code scanner searches with the
 * stock Oniguruma f95747b (experiment #1).
 * Build: cc -O2 -o replay replay.c -I<prefix>/include -L<prefix>/lib -lonig
 * Input (stdin), tab-separated, byte strings hex-encoded:
 *   S  scanner_id  pattern_hex,pattern_hex,...
 *   Q  query_id  scanner_id  subject_hex  start  options
 * Output: query_id  index  from  to   (index -1: no match; -2: compile error)
 * Semantics follow vscode-oniguruma findNextOnigScannerMatch: syntax
 * ONIG_SYNTAX_DEFAULT, ONIG_OPTION_CAPTURE_GROUP, UTF-8; subjects shorter
 * than 1000 bytes use onig_regset_search with ONIG_REGSET_POSITION_LEAD,
 * longer ones search each regex and keep the leftmost (first on ties).
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "oniguruma.h"

#define MAXSCAN 65536
static OnigRegSet* sets[MAXSCAN];
static regex_t** regs[MAXSCAN];
static int counts[MAXSCAN];
static int bad[MAXSCAN];

static size_t unhex(const char* h, UChar* out) {
  size_t n = 0;
  for (; h[0] && h[1] && h[0] != ',' ; h += 2) {
    int a = h[0] <= '9' ? h[0] - '0' : h[0] - 'a' + 10;
    int b = h[1] <= '9' ? h[1] - '0' : h[1] - 'a' + 10;
    out[n++] = (UChar)(a * 16 + b);
  }
  return n;
}

int main(void) {
  OnigEncoding enc = ONIG_ENCODING_UTF8;
  onig_initialize(&enc, 1);
  size_t cap = 1 << 24;
  char* line = malloc(cap);
  UChar* buf = malloc(cap);
  while (fgets(line, (int)cap, stdin)) {
    line[strcspn(line, "\n")] = 0;
    if (line[0] == 'S') {
      char* p = line + 2;
      int id = atoi(p);
      p = strchr(p, '\t') + 1;
      int n = 1;
      for (char* q = p; *q; q++) if (*q == ',') n++;
      if (*p == 0) n = 0;
      regs[id] = calloc(n ? n : 1, sizeof(regex_t*));
      counts[id] = n;
      for (int i = 0; i < n; i++) {
        size_t len = unhex(p, buf);
        OnigErrorInfo ei;
        if (onig_new(&regs[id][i], buf, buf + len, ONIG_OPTION_CAPTURE_GROUP,
                     enc, ONIG_SYNTAX_DEFAULT, &ei) != ONIG_NORMAL) {
          bad[id] = 1; regs[id][i] = NULL;
        }
        p = strchr(p, ',');
        if (p) p++; else break;
      }
      if (!bad[id] && n > 0)
        onig_regset_new(&sets[id], n, regs[id]);
    } else if (line[0] == 'Q') {
      char* f[6]; int k = 0;
      for (char* t = strtok(line, "\t"); t && k < 6; t = strtok(NULL, "\t")) f[k++] = t;
      if (k < 6) continue;
      int sid = atoi(f[2]);
      size_t len = unhex(f[3], buf);
      int start = atoi(f[4]);
      OnigOptionType opt = (OnigOptionType)strtoul(f[5], NULL, 10);
      if (bad[sid]) { printf("%s\t-2\t-\t-\n", f[1]); continue; }
      if (counts[sid] == 0) { printf("%s\t-1\t-\t-\n", f[1]); continue; }
      if (len < 1000) {
        int pos;
        int idx = onig_regset_search(sets[sid], buf, buf + len, buf + start, buf + len,
                                     ONIG_REGSET_POSITION_LEAD, opt, &pos);
        if (idx < 0) printf("%s\t%d\t-\t-\n", f[1], idx == ONIG_MISMATCH ? -1 : idx);
        else {
          OnigRegion* r = onig_regset_get_region(sets[sid], idx);
          printf("%s\t%d\t%d\t%d\n", f[1], idx, r->beg[0], r->end[0]);
        }
      } else {
        int best = -1, bb = 0, be = 0;
        OnigRegion* r = onig_region_new();
        for (int i = 0; i < counts[sid]; i++) {
          int s = onig_search(regs[sid][i], buf, buf + len, buf + start, buf + len, r, opt);
          if (s >= 0 && (best < 0 || r->beg[0] < bb)) { best = i; bb = r->beg[0]; be = r->end[0]; }
          if (s >= 0 && r->beg[0] == start) break;
        }
        onig_region_free(r, 1);
        if (best < 0) printf("%s\t-1\t-\t-\n", f[1]);
        else printf("%s\t%d\t%d\t%d\n", f[1], best, bb, be);
      }
    }
  }
  return 0;
}
