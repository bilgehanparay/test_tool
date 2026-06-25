include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(test_tool_supports_sanitizers)
  # Emscripten doesn't support sanitizers
  if(EMSCRIPTEN)
    set(SUPPORTS_UBSAN OFF)
    set(SUPPORTS_ASAN OFF)
  elseif((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(test_tool_setup_options)
  option(test_tool_ENABLE_HARDENING "Enable hardening" ON)
  option(test_tool_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    test_tool_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    test_tool_ENABLE_HARDENING
    OFF)

  test_tool_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR test_tool_PACKAGING_MAINTAINER_MODE)
    option(test_tool_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(test_tool_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(test_tool_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(test_tool_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(test_tool_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(test_tool_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(test_tool_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(test_tool_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(test_tool_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(test_tool_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(test_tool_ENABLE_PCH "Enable precompiled headers" OFF)
    option(test_tool_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(test_tool_ENABLE_IPO "Enable IPO/LTO" ON)
    option(test_tool_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(test_tool_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(test_tool_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(test_tool_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(test_tool_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(test_tool_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(test_tool_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(test_tool_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(test_tool_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(test_tool_ENABLE_PCH "Enable precompiled headers" OFF)
    option(test_tool_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      test_tool_ENABLE_IPO
      test_tool_WARNINGS_AS_ERRORS
      test_tool_ENABLE_SANITIZER_ADDRESS
      test_tool_ENABLE_SANITIZER_LEAK
      test_tool_ENABLE_SANITIZER_UNDEFINED
      test_tool_ENABLE_SANITIZER_THREAD
      test_tool_ENABLE_SANITIZER_MEMORY
      test_tool_ENABLE_UNITY_BUILD
      test_tool_ENABLE_CLANG_TIDY
      test_tool_ENABLE_CPPCHECK
      test_tool_ENABLE_COVERAGE
      test_tool_ENABLE_PCH
      test_tool_ENABLE_CACHE)
  endif()

  test_tool_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (test_tool_ENABLE_SANITIZER_ADDRESS OR test_tool_ENABLE_SANITIZER_THREAD OR test_tool_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(test_tool_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(test_tool_global_options)
  if(test_tool_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    test_tool_enable_ipo()
  endif()

  test_tool_supports_sanitizers()

  if(test_tool_ENABLE_HARDENING AND test_tool_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR test_tool_ENABLE_SANITIZER_UNDEFINED
       OR test_tool_ENABLE_SANITIZER_ADDRESS
       OR test_tool_ENABLE_SANITIZER_THREAD
       OR test_tool_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${test_tool_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${test_tool_ENABLE_SANITIZER_UNDEFINED}")
    test_tool_enable_hardening(test_tool_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(test_tool_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(test_tool_warnings INTERFACE)
  add_library(test_tool_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  test_tool_set_project_warnings(
    test_tool_warnings
    ${test_tool_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  include(cmake/Linker.cmake)
  # Must configure each target with linker options, we're avoiding setting it globally for now

  if(NOT EMSCRIPTEN)
    include(cmake/Sanitizers.cmake)
    test_tool_enable_sanitizers(
      test_tool_options
      ${test_tool_ENABLE_SANITIZER_ADDRESS}
      ${test_tool_ENABLE_SANITIZER_LEAK}
      ${test_tool_ENABLE_SANITIZER_UNDEFINED}
      ${test_tool_ENABLE_SANITIZER_THREAD}
      ${test_tool_ENABLE_SANITIZER_MEMORY})
  endif()

  set_target_properties(test_tool_options PROPERTIES UNITY_BUILD ${test_tool_ENABLE_UNITY_BUILD})

  if(test_tool_ENABLE_PCH)
    target_precompile_headers(
      test_tool_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(test_tool_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    test_tool_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(test_tool_ENABLE_CLANG_TIDY)
    test_tool_enable_clang_tidy(test_tool_options ${test_tool_WARNINGS_AS_ERRORS})
  endif()

  if(test_tool_ENABLE_CPPCHECK)
    test_tool_enable_cppcheck(${test_tool_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(test_tool_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    test_tool_enable_coverage(test_tool_options)
  endif()

  if(test_tool_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(test_tool_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(test_tool_ENABLE_HARDENING AND NOT test_tool_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR test_tool_ENABLE_SANITIZER_UNDEFINED
       OR test_tool_ENABLE_SANITIZER_ADDRESS
       OR test_tool_ENABLE_SANITIZER_THREAD
       OR test_tool_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    test_tool_enable_hardening(test_tool_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
