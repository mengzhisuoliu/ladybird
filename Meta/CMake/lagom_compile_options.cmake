include(${CMAKE_CURRENT_LIST_DIR}/common_compile_options.cmake)

add_cxx_compile_options(-Wno-maybe-uninitialized)
add_cxx_compile_options(-Wno-shorten-64-to-32)

if(NOT MSVC)
    add_cxx_compile_options(-fsigned-char)
    add_cxx_compile_options(-ggnu-pubnames)
else()
    # full symbolic debugginng information
    add_cxx_compile_options(/Z7)
endif()

include(CheckPIESupported)
check_pie_supported(LANGUAGES CXX)
if(CMAKE_CXX_LINK_PIE_SUPPORTED)
    set(CMAKE_POSITION_INDEPENDENT_CODE ON)
endif()

if (LINUX)
    add_cxx_compile_definitions(_FILE_OFFSET_BITS=64)
endif()

if (APPLE)
    list(APPEND CMAKE_PREFIX_PATH /opt/homebrew)
endif()

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    if (NOT MSVC)
        add_cxx_compile_options(-ggdb3)
    endif()
    add_cxx_compile_options(-Og)
elseif (CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
    add_cxx_compile_options(-O2)
    if (NOT MSVC)
        add_cxx_compile_options(-g1)
    endif()
else()
    add_cxx_compile_options(-O3)

    if (ENABLE_LTO_FOR_RELEASE)
        include(CheckIPOSupported)
        check_ipo_supported(RESULT IPO_AVAILABLE OUTPUT output)
        if(IPO_AVAILABLE)
            set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
        else()
            message(WARNING "Not enabling IPO as it is not supported: ${output}")
        endif()
    endif()
endif()

function(add_cxx_linker_flag_if_supported flag)
    include(CheckLinkerFlag)

    check_linker_flag(CXX ${flag} LAGOM_LINKER_SUPPORTS_${flag})
    if (${LAGOM_LINKER_SUPPORTS_${flag}})
        add_cxx_link_options(${flag})
    endif()
endfunction()

if (NOT WIN32)
    add_cxx_linker_flag_if_supported(LINKER:--gdb-index)

    if (NOT ENABLE_FUZZERS)
        add_cxx_linker_flag_if_supported(LINKER:-Bsymbolic-non-weak-functions)
    endif()
endif()

if (NOT WIN32 AND NOT APPLE AND NOT ENABLE_FUZZERS)
    # NOTE: Assume ELF
    # NOTE: --no-undefined is not compatible with clang sanitizer runtimes
    if (CMAKE_CXX_COMPILER_ID MATCHES "Clang$" AND (ENABLE_ADDRESS_SANITIZER OR ENABLE_MEMORY_SANITIZER OR ENABLE_UNDEFINED_SANITIZER OR ENABLE_LAGOM_COVERAGE_COLLECTION))
        add_link_options(LINKER:--allow-shlib-undefined)
        add_link_options(LINKER:-z,undefs)
    else()
        add_link_options(LINKER:-z,defs)
        add_link_options(LINKER:--no-undefined)
        # FIXME: Remove this once FreeBSD exports environ from libc
        if (NOT CMAKE_SYSTEM_NAME MATCHES "FreeBSD")
            add_link_options(LINKER:--no-allow-shlib-undefined)
        endif()
    endif()
endif()

if (ENABLE_LAGOM_COVERAGE_COLLECTION)
    if (CMAKE_CXX_COMPILER_ID MATCHES "Clang$" AND NOT ENABLE_FUZZERS)
        add_cxx_compile_options(-fprofile-instr-generate -fcoverage-mapping)
        add_cxx_link_options(-fprofile-instr-generate)
    else()
        message(FATAL_ERROR
            "Collecting code coverage is unsupported in this configuration.")
    endif()
endif()
