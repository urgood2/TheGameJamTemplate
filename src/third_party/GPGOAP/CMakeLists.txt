
cmake_minimum_required(VERSION 3.5)

# build libgpgoap as a static lib
add_library(gpgoap STATIC
	astar.c
	goap.c
)


#LOCAL_CFLAGS += -std=c99
# Set the output directory for the static library
set_target_properties(gpgoap PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
)

# Install the static library
install(TARGETS gpgoap
        ARCHIVE DESTINATION lib
)


