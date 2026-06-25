macro(test_tool_configure_linker project_name)
  set(test_tool_USER_LINKER_OPTION
    "DEFAULT"
      CACHE STRING "Linker to be used")
    set(test_tool_USER_LINKER_OPTION_VALUES "DEFAULT" "SYSTEM" "LLD" "GOLD" "BFD" "MOLD" "SOLD" "APPLE_CLASSIC" "MSVC")
  set_property(CACHE test_tool_USER_LINKER_OPTION PROPERTY STRINGS ${test_tool_USER_LINKER_OPTION_VALUES})
  list(
    FIND
    test_tool_USER_LINKER_OPTION_VALUES
    ${test_tool_USER_LINKER_OPTION}
    test_tool_USER_LINKER_OPTION_INDEX)

  if(${test_tool_USER_LINKER_OPTION_INDEX} EQUAL -1)
    message(
      STATUS
        "Using custom linker: '${test_tool_USER_LINKER_OPTION}', explicitly supported entries are ${test_tool_USER_LINKER_OPTION_VALUES}")
  endif()

  set_target_properties(${project_name} PROPERTIES LINKER_TYPE "${test_tool_USER_LINKER_OPTION}")
endmacro()
