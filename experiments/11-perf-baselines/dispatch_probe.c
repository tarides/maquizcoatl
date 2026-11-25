/* Experiment #11: prints whether a build compiles the direct-threaded
 * dispatch of regexec.c, using that build's flags and config.h. */
#include "regint.h"
#include <stdio.h>
int main(void)
{
#ifdef USE_DIRECT_THREADED_CODE
  puts("USE_DIRECT_THREADED_CODE defined: direct-threaded dispatch");
#else
  puts("USE_DIRECT_THREADED_CODE undefined: switch dispatch");
#endif
  return 0;
}
