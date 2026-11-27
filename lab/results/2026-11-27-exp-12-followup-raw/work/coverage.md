| Family | Calls admitted | Weighted (VS Code frequency profile) | Pattern entries with an admitted call |
|---|---:|---:|---:|
| jq | 91 / 217 (41.9%) |  | 10 / 44 |
| php | 63 / 421 (15.0%) |  | 21 / 187 |
| vscode | 77,067 / 429,020 (18.0%) | 127,660 / 759,850 (16.8%) | 277 / 4,221 |
| longphp | 10 / 18 (55.6%) |  | 1 / 5 |

Rejection reasons (first rule failed; calls, and weighted calls for VS Code):

- jq: `compile options` 35; `recognise: (? group` 34; `recognise: +` 29; `recognise: anchor` 11; `recognise: character class` 6; `recognise: anychar` 5; `recognise: escape \b` 4; `recognise: non-ASCII byte` 2
- php: `encoding not UTF-8` 151; `recognise: character class` 45; `compile options` 23; `recognise: anychar` 20; `recognise: (? group` 20; `recognise: escape \d` 19; `recognise: anchor` 17; `recognise: escape \w` 14; `recognise: non-ASCII byte` 11; `recognise: escape \S` 7; `recognise: escape \s` 6; `recognise: escape \1` 4; `recognise: escape \Z` 3; `recognise: ?` 3; `backward call` 2; `recognise: escape \A` 2; `recognise: escape \W` 2; `recognise: escape \D` 2; `recognise: escape \b` 2; `recognise: escape \B` 2; `recognise: +` 2; `syntax not ONIGURUMA, RUBY or PERL_NG` 1
- vscode: `recognise: (? group` 190,297 (weighted 392,120); `recognise: escape \b` 63,103 (weighted 79,600); `recognise: anchor` 31,261 (weighted 50,552); `recognise: character class` 24,913 (weighted 46,023); `recognise: escape \s` 17,909 (weighted 29,465); `recognise: ?` 8,025 (weighted 9,254); `recognise: {` 3,432 (weighted 5,996); `recognise: anychar` 1,980 (weighted 2,531); `recognise: escape \n` 1,663 (weighted 1,880); `recognise: escape \!` 1,401 (weighted 3,362); `recognise: escape \G` 1,225 (weighted 1,288); `recognise: escape \=` 1,217 (weighted 3,139); `recognise: escape \ï` 1,150 (weighted 1,754); `recognise: escape \:` 773 (weighted 1,170); `recognise: +` 680 (weighted 719); `recognise: escape \B` 632 (weighted 632); `recognise: escape \#` 530 (weighted 573); `recognise: escape \w` 470 (weighted 547); `recognise: } (literal, left out conservatively)` 434 (weighted 591); `recognise: escape \d` 180 (weighted 189); `recognise: escape \`` 130 (weighted 150); `recognise: escape \h` 117 (weighted 117); `recognise: escape \,` 91 (weighted 93); `recognise: escape \'` 57 (weighted 67); `recognise: \x{} >= 0x80` 54 (weighted 55); `recognise: ] (literal, left out conservatively)` 44 (weighted 51); `recognise: escape \S` 42 (weighted 103); `recognise: escape \A` 37 (weighted 38); `recognise: escape \@` 34 (weighted 35); `recognise: escape \;` 31 (weighted 49); `recognise: escape \~` 20 (weighted 22); `recognise: escape \t` 20 (weighted 24); `recognise: escape \r` 1 (weighted 1)
- longphp: `compile options` 5; `recognise: escape \s` 3

Large shape: 14 log patterns and 15 source patterns kept of experiment #12's 16 and 16; left out: log `\=` (recognise: escape \=); log `\s*(\[)` (recognise: escape \s); src `\=` (recognise: escape \=)
