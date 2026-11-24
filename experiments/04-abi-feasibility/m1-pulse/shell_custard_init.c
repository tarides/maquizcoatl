/* shell_custard_init.c: hand-written C shell of mechanism 1b (Custard).
   Custard's direct C backend leaves global records zero in .bss and
   fills them in custard_init_globals() at run time; libonig's data
   symbols must be valid as soon as the library is loaded, so a load-time
   constructor calls it. Outside the proofs. */
void custard_init_globals(void);

__attribute__((constructor))
static void onig_stub_custard_init(void)
{
  custard_init_globals();
}
