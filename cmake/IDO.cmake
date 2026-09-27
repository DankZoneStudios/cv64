set(IDO_DOWNLOAD_VERSION "v1.2")
# or pin a specific version - e.g. `set(IDO_DOWNLOAD_VERSION "v0.6")`

if(WIN32 OR APPLE)
  message(FATAL_ERROR
    "The reproducible CV64 build currently supports Linux/WSL only."
  )
else()
  set(IDO_DETECTED_OS "linux")
  set(IDO_5_3_EXPECTED_SHA256 "ab5c741561f80913d58c8b074771f23941a3edd312505a8ebed6d1dfeb65e506")
  set(IDO_7_1_EXPECTED_SHA256 "0d411696e178fcca34c31c3bf02011b928d7fd9c1fa7f8bf45070e0781b58e15")
endif()

string(
  CONCAT IDO_5_3_DOWNLOAD_URL
         "https://github.com" # GitHub
         "/decompals/ido-static-recomp" # repository
         "/releases/download/${IDO_DOWNLOAD_VERSION}" # release version
         "/ido-5.3-recomp-${IDO_DETECTED_OS}.tar.gz" # artifact
)
string(
  CONCAT IDO_7_1_DOWNLOAD_URL
         "https://github.com" # GitHub
         "/decompals/ido-static-recomp" # repository
         "/releases/download/${IDO_DOWNLOAD_VERSION}" # release version
         "/ido-7.1-recomp-${IDO_DETECTED_OS}.tar.gz" # artifact
)

set(IDO_DOWNLOAD_URLS ${IDO_5_3_DOWNLOAD_URL} ${IDO_7_1_DOWNLOAD_URL})
set(IDO_EXPECTED_SHA256S ${IDO_5_3_EXPECTED_SHA256} ${IDO_7_1_EXPECTED_SHA256})

set(IDO_5_3_DOWNLOAD_LOCATION "${CMAKE_SOURCE_DIR}/tools/ido/ido-5.3-recomp-${IDO_DETECTED_OS}.tar.gz")
set(IDO_7_1_DOWNLOAD_LOCATION "${CMAKE_SOURCE_DIR}/tools/ido/ido-7.1-recomp-${IDO_DETECTED_OS}.tar.gz")

set(IDO_DOWNLOAD_LOCATIONS ${IDO_5_3_DOWNLOAD_LOCATION} ${IDO_7_1_DOWNLOAD_LOCATION})

set(IDO_5_3_EXTRACT_LOCATION "${CMAKE_SOURCE_DIR}/tools/ido/${IDO_DETECTED_OS}/5.3/")
set(IDO_7_1_EXTRACT_LOCATION "${CMAKE_SOURCE_DIR}/tools/ido/${IDO_DETECTED_OS}/7.1/")

set(IDO_EXTRACT_LOCATIONS ${IDO_5_3_EXTRACT_LOCATION} ${IDO_7_1_EXTRACT_LOCATION})

# Downloads prebuilt IDO 5.3/7.1 binaries for your OS
function(download_ido_release_artifact url to expected_hash)
  message(STATUS "Downloading ${url}")
  file(
    DOWNLOAD "${url}" "${to}"
    EXPECTED_HASH "SHA256=${expected_hash}"
    STATUS download_status
    LOG download_log
  )

  list(GET download_status 0 download_error_code)
  list(GET download_status 1 download_error_message)

  if(NOT download_error_code EQUAL 0)
    file(REMOVE "${to}")
    message(FATAL_ERROR
      "Failed to download IDO compiler archive.\n"
      "URL: ${url}\n"
      "Error: ${download_error_message}\n"
      "${download_log}"
    )
  endif()
endfunction()

# Extracts IDO binaries from the containing archive
function(extract_ido_archive archive destination)
  message(STATUS "Extracting ${archive} to ${destination}")
  # cmake-lint: disable=E1126
  file(
    ARCHIVE_EXTRACT
    INPUT "${archive}"
    DESTINATION "${destination}"
  )
endfunction()

# Make IDO 5.3/7.1 binaries available for use in main build
function(download_and_extract_ido)
  foreach(
    url
    location
    destination
    expected_hash
    IN
    ZIP_LISTS
    IDO_DOWNLOAD_URLS
    IDO_DOWNLOAD_LOCATIONS
    IDO_EXTRACT_LOCATIONS
    IDO_EXPECTED_SHA256S)
    download_ido_release_artifact("${url}" "${location}" "${expected_hash}")
    extract_ido_archive("${location}" "${destination}")
  endforeach()
  file(REMOVE ${IDO_DOWNLOAD_LOCATIONS})
endfunction()

if(NOT EXISTS "${IDO_5_3_EXTRACT_LOCATION}/cc" OR NOT EXISTS "${IDO_7_1_EXTRACT_LOCATION}/cc")
  download_and_extract_ido()
else()
  message(STATUS "Ido compilers exist")
endif()
