import Lake
open Lake DSL

package e06

lean_lib Spec
lean_lib Cases

@[default_target]
lean_exe lean_e06 where
  root := `Main
