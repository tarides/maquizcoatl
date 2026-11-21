# Mechanism 1 stub: the C extracted from OnigStub.fst by one emitter
# (EMITTER=krml: KaRaMeL, --codegen KrmlC; EMITTER=custard: Custard,
# --codegen C) plus the hand-written C shell, built like upstream:
# soname libonig.so.5, three file names, oniguruma.pc (criterion 4).
cmake_minimum_required(VERSION 3.16)
project(onig_stub_m1 VERSION 6.9.10 LANGUAGES C)
option(BUILD_SHARED_LIBS "Build shared libraries" ON)
option(ENABLE_POSIX_API "Include POSIX API" OFF)
set(EMITTER "krml" CACHE STRING "krml or custard")
set(ONIG_INCLUDE "" CACHE PATH "upstream public headers")
set(GEN_DIR "" CACHE PATH "directory holding the extracted Custard.c/.h")
set(KRML_INCLUDE "" CACHE STRING "krml include dirs (EMITTER=krml)")
set(SHELL_C ${CMAKE_CURRENT_SOURCE_DIR}/../m2-c/stub_shell.c)

# The extracted C is compiled in its own target: its header and
# upstream's declare the same functions with different (ABI-equivalent)
# pointer types, so they never meet in one translation unit.
add_library(onig_gen OBJECT ${GEN_DIR}/Custard.c)
set_target_properties(onig_gen PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(onig_gen PRIVATE ${GEN_DIR})
if(EMITTER STREQUAL "krml")
  separate_arguments(kinc UNIX_COMMAND "${KRML_INCLUDE}")
  target_include_directories(onig_gen PRIVATE ${kinc})
  # exact data symbol names: KaRaMeL keeps the F* names (onigEncodingUTF8)
  target_compile_options(onig_gen PRIVATE -include ${CMAKE_CURRENT_SOURCE_DIR}/krml_names.h)
endif()

set(shell ${SHELL_C} ${CMAKE_CURRENT_SOURCE_DIR}/shell_data.c)
if(EMITTER STREQUAL "custard")
  list(APPEND shell ${CMAKE_CURRENT_SOURCE_DIR}/shell_custard_init.c)
endif()
add_library(onig ${shell} $<TARGET_OBJECTS:onig_gen>)
# Export only the public API (spec/deviations.md, DEV-005): an
# anonymous version script (no symbol versions, like upstream) listing
# the public names; everything else becomes local. No -Bsymbolic and no
# protected visibility: public data symbols stay preemptible.
set(EXPORT_MAP "" CACHE FILEPATH "version script from exports.sh (empty: export everything)")
if(EXPORT_MAP)
  target_link_options(onig PRIVATE "-Wl,--version-script=${EXPORT_MAP}")
  set_target_properties(onig PROPERTIES LINK_DEPENDS ${EXPORT_MAP})
endif()
set(EXTRA_LINK_FLAGS "" CACHE STRING "negative controls only (exports.sh: -Wl,-Bsymbolic)")
if(EXTRA_LINK_FLAGS)
  separate_arguments(xlf UNIX_COMMAND "${EXTRA_LINK_FLAGS}")
  target_link_options(onig PRIVATE ${xlf})
endif()
target_include_directories(onig PRIVATE ${ONIG_INCLUDE})
if(NOT EMSCRIPTEN)
  set_target_properties(onig PROPERTIES SOVERSION 5 VERSION 5.5.0)
endif()

set(hdrs ${ONIG_INCLUDE}/oniguruma.h ${ONIG_INCLUDE}/oniggnu.h)
if(ENABLE_POSIX_API)
  list(APPEND hdrs ${ONIG_INCLUDE}/onigposix.h)
endif()
include(GNUInstallDirs)
install(TARGETS onig LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
                     ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(FILES ${hdrs} DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
set(onig_pkgconfig_libdir ${CMAKE_INSTALL_FULL_LIBDIR})
set(PACKAGE_VERSION ${PROJECT_VERSION})
configure_file(${ONIG_INCLUDE}/../oniguruma.pc.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/oniguruma.pc @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/oniguruma.pc DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig)
