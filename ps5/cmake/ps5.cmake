# SpaceRanger for the PlayStation 5 - what the console adds to the build.
#
# CMakeLists.txt includes this right after project() when the payload SDK's
# toolchain is in use (it sets PS5); ps5/tools/build.sh configures that way.
# Besides the PS5 branches in the dependencies' patches (patches/deps), the
# console needs:
#
#   SDL2 and FreeType   built for the console by ps5/tools/setup-libs.sh: SDL2
#                       with the drivers in ps5/sdl2 (video, AudioOut, the pad)
#   file_to_c           RT64 runs it during the build, so it is the build
#                       machine's (RT64_FILE_TO_C)
#   ps5_platform        the console's start-up, pad and sound (ps5/src), linked
#                       whole into the title
#   the link            PS5_Vulkan's, with RADV (ps5/tools/link-title.sh), which
#                       also packages the title folder, dist/<TITLE_ID>/
#
# SPDX-License-Identifier: MIT

set(PS5_VULKAN_DIR "${CMAKE_SOURCE_DIR}/../PS5_Vulkan" CACHE PATH
	"PS5_Vulkan, with its RADV release archive, native tool and libc.prx built")
set(PS5_LIBS_DIR "${CMAKE_SOURCE_DIR}/.deps/native" CACHE PATH
	"where ps5/tools/setup-libs.sh installed SDL2 and FreeType for the console")
get_filename_component(PS5_VULKAN_DIR "${PS5_VULKAN_DIR}" ABSOLUTE)
set(ps5 ${CMAKE_CURRENT_LIST_DIR}/..)
get_filename_component(ps5 "${ps5}" ABSOLUTE)
foreach(required
		"${PS5_VULKAN_DIR}/.deps/native/radv-release/lib/libvulkan_radeon.ps5.a"
		"${PS5_VULKAN_DIR}/build/host/ps5-native-tool"
		"${PS5_LIBS_DIR}/sdl2/lib/cmake/SDL2/SDL2Config.cmake"
		"${PS5_LIBS_DIR}/freetype/lib/libfreetype.a")
	if(NOT EXISTS "${required}")
		message(FATAL_ERROR "PS5: ${required} is missing (ps5/tools/build.sh sets everything up; see docs/PS5.md)")
	endif()
endforeach()
message(STATUS "PS5: PS5_Vulkan at ${PS5_VULKAN_DIR}, SDL2 and FreeType in ${PS5_LIBS_DIR}")

# -fno-omit-frame-pointer: the console's crash backtraces are frame-pointer walks.
add_compile_options(-g1 -ffunction-sections -fdata-sections -fno-omit-frame-pointer)
# An init array, in the order the source has: ps5/tools/cc-init-array.sh has the reason
set(CMAKE_C_COMPILER_LAUNCHER sh ${ps5}/tools/cc-init-array.sh)
set(CMAKE_CXX_COMPILER_LAUNCHER sh ${ps5}/tools/cc-init-array.sh)

# SDL2 and FreeType: the toolchain searches the SDK's sysroot only
list(APPEND CMAKE_FIND_ROOT_PATH "${PS5_LIBS_DIR}/sdl2" "${PS5_LIBS_DIR}/freetype")
list(APPEND CMAKE_PREFIX_PATH /)

# RT64's build-time tool, built for the build machine by ps5/tools/build.sh
set(RT64_FILE_TO_C "${CMAKE_BINARY_DIR}/host/file_to_c" CACHE FILEPATH "file_to_c for the build machine")

# The console: start-up, klog, the pad, sound, the title's exit, and the libc
# names a title cannot import
add_library(ps5_platform STATIC ${ps5}/src/platform.c ${ps5}/src/shims.c ${ps5}/src/startup.c)
target_include_directories(ps5_platform PUBLIC ${ps5}/src)
file(READ ${ps5}/sce_sys/param.json ps5_param_json)
string(JSON PS5_TITLE_NAME GET "${ps5_param_json}" localizedParameters en-US titleName)
string(JSON PS5_TITLE_ID GET "${ps5_param_json}" titleId)
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${ps5}/sce_sys/param.json)
message(STATUS "PS5: title ${PS5_TITLE_NAME} (${PS5_TITLE_ID}), packaged in dist/${PS5_TITLE_ID}/")
target_compile_definitions(ps5_platform PRIVATE "PS5_TITLE_NAME=\"${PS5_TITLE_NAME}\"")
set_target_properties(ps5_platform PROPERTIES ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
# By its file: it is linked whole into the title (the start-up constructor and
# the CRT's catchReturnFromMain have no caller in the game)
set(ps5_platform_archive ${CMAKE_BINARY_DIR}/libps5_platform.a)

# The link: every object and archive CMake would hand the linker goes to
# PS5_Vulkan's recipe instead (RADV, the platform layer, the CRT, the fake SELF)
set(CMAKE_CXX_LINK_EXECUTABLE
	"bash ${ps5}/tools/link-title.sh ${CMAKE_BINARY_DIR} ${PS5_VULKAN_DIR} ${PS5_PAYLOAD_SDK} <OBJECTS> --whole-archive ${ps5_platform_archive} --no-whole-archive <LINK_LIBRARIES> -o <TARGET>")

# Once every target exists: zstd without its trace hooks, and the game links
# the platform archive and re-links when the packaging inputs change
function(ps5_after_game)
	# zstd's tracing hooks (RT64's) are weak symbols for a tool to fill in: a
	# title may not leave a symbol undefined, so tracing is compiled out
	if(TARGET libzstd_static)
		target_compile_definitions(libzstd_static PRIVATE ZSTD_TRACE=0)
	endif()
	if(TARGET spaceranger)
		add_dependencies(spaceranger ps5_platform)
		set_property(TARGET spaceranger APPEND PROPERTY LINK_DEPENDS
			${ps5}/tools/link-title.sh ${ps5}/sce_sys/param.json ${ps5_platform_archive})
	endif()
endfunction()
cmake_language(DEFER DIRECTORY ${CMAKE_SOURCE_DIR} CALL ps5_after_game)
