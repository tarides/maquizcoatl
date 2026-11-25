import Lake
open Lake DSL

-- experiment #6 milestone 2 (copied as lakefile.lean into the build directory)
package e06m2

lean_lib Tables
lean_lib Spec2
lean_lib Cases

@[default_target]
lean_exe lean_e06m2 where
  root := `Main2
