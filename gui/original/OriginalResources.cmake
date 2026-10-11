# Include this fragment after creating the Qt target and enabling Qt 6 CMake integration.
# It packages the exact qrc aliases declared by original.qrc; it does not create a UI target.
include_guard(GLOBAL)
set(DJI_STUDIO_ORIGINAL_QML_IMPORT_PATH "qrc:/")
set(DJI_STUDIO_ORIGINAL_MAIN_QML_URL "qrc:/qml/Main.qml")
set(_DJI_STUDIO_ORIGINAL_RESOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}")

function(dji_studio_attach_original_resources target_name)
  if(NOT TARGET "${target_name}")
    message(FATAL_ERROR "dji_studio_attach_original_resources: target '${target_name}' does not exist")
  endif()
  set_property(TARGET "${target_name}" PROPERTY AUTORCC ON)
  target_sources("${target_name}" PRIVATE "${_DJI_STUDIO_ORIGINAL_RESOURCE_DIR}/original.qrc")
endfunction()
