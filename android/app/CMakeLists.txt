cmake_minimum_required(VERSION 3.4.1)

add_library(
    fractal_engine
    SHARED
    src/main/cpp/engine.c
)

find_library(
    log-lib
    log
)

target_link_libraries(
    fractal_engine
    ${log-lib}
)
