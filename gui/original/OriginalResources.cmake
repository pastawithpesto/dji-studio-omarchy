# Include this fragment from a Qt 6 CMake project.
# The resource aliases are intended for a separate original-shell executable.
include_guard(GLOBAL)

set(DJI_STUDIO_ORIGINAL_QML_IMPORT_PATH "qrc:/")
set(DJI_STUDIO_ORIGINAL_MAIN_QML_URL "qrc:/qml/Main.qml")

function(_dji_studio_original_resources_reject_direct_qrc target_name operation)
  get_target_property(_dji_studio_original_sources "${target_name}" SOURCES)
  if(_dji_studio_original_sources)
    foreach(_dji_studio_original_source IN LISTS _dji_studio_original_sources)
      if(_dji_studio_original_source MATCHES "[.]qrc$")
        message(FATAL_ERROR
          "${operation}: target '${target_name}' already has a direct qrc source "
          "('${_dji_studio_original_source}'). The expanded original bundle shares "
          "1,458 compiled-EXE aliases with the existing GUI resource manifest; "
          "use a separate original-shell target.")
      endif()
    endforeach()
  endif()
endfunction()

function(dji_studio_declare_original_shell_target target_name)
  if(NOT TARGET "${target_name}")
    message(FATAL_ERROR
      "dji_studio_declare_original_shell_target: target '${target_name}' does not exist")
  endif()

  get_target_property(_dji_studio_original_type "${target_name}" TYPE)
  if(NOT _dji_studio_original_type STREQUAL "EXECUTABLE")
    message(FATAL_ERROR
      "dji_studio_declare_original_shell_target: '${target_name}' must be a separate executable target")
  endif()

  get_target_property(_dji_studio_original_declared "${target_name}" DJI_STUDIO_ORIGINAL_SHELL_TARGET)
  if(_dji_studio_original_declared)
    message(FATAL_ERROR
      "dji_studio_declare_original_shell_target: '${target_name}' is already declared")
  endif()

  _dji_studio_original_resources_reject_direct_qrc(
    "${target_name}" "dji_studio_declare_original_shell_target")
  set_property(TARGET "${target_name}" PROPERTY DJI_STUDIO_ORIGINAL_SHELL_TARGET TRUE)
  set_property(TARGET "${target_name}" PROPERTY DJI_STUDIO_ORIGINAL_QML_IMPORT_PATH "qrc:/")
  set_property(TARGET "${target_name}" PROPERTY DJI_STUDIO_ORIGINAL_MAIN_QML_URL "qrc:/qml/Main.qml")
endfunction()

function(dji_studio_attach_original_resources target_name)
  if(NOT TARGET "${target_name}")
    message(FATAL_ERROR
      "dji_studio_attach_original_resources: target '${target_name}' does not exist")
  endif()

  get_target_property(_dji_studio_original_declared "${target_name}" DJI_STUDIO_ORIGINAL_SHELL_TARGET)
  if(NOT _dji_studio_original_declared)
    message(FATAL_ERROR
      "dji_studio_attach_original_resources: '${target_name}' was not declared as a separate original-shell executable")
  endif()

  get_target_property(_dji_studio_original_attached "${target_name}" DJI_STUDIO_ORIGINAL_RESOURCES_ATTACHED)
  if(_dji_studio_original_attached)
    message(FATAL_ERROR
      "dji_studio_attach_original_resources: resources are already attached to '${target_name}'")
  endif()

  _dji_studio_original_resources_reject_direct_qrc(
    "${target_name}" "dji_studio_attach_original_resources")
  set_property(TARGET "${target_name}" PROPERTY AUTORCC ON)
  target_sources("${target_name}" PRIVATE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/original.qrc")
  set_property(TARGET "${target_name}" PROPERTY DJI_STUDIO_ORIGINAL_RESOURCES_ATTACHED TRUE)
endfunction()
