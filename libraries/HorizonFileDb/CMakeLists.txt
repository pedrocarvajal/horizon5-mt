cmake_minimum_required(VERSION 3.20)
project(HorizonFileDb LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(HorizonFileDb SHARED
    HorizonFileDb.cpp
    HorizonFileDb.h
    constants/Limits.h
    entities/Document.h
    entities/Collection.h
    entities/Database.h
    entities/Query.h
    services/DatabaseManager.h
    services/CollectionManager.h
    services/QueryEngine.h
    services/UuidGenerator.h
    services/FileIO.h
)

target_include_directories(HorizonFileDb PRIVATE vendor)
target_compile_definitions(HorizonFileDb PRIVATE HORIZON_FDB_EXPORTS)

if(MSVC)
    target_compile_options(HorizonFileDb PRIVATE /W4 /O2)
    target_link_libraries(HorizonFileDb PRIVATE bcrypt)
elseif(MINGW)
    target_link_options(HorizonFileDb PRIVATE -static-libgcc -static-libstdc++ -static)
    target_link_libraries(HorizonFileDb PRIVATE -lbcrypt -lwinpthread)
endif()

set_target_properties(HorizonFileDb PROPERTIES
    OUTPUT_NAME "HorizonFileDb"
    PREFIX ""
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

install(TARGETS HorizonFileDb
    RUNTIME DESTINATION lib
    LIBRARY DESTINATION lib
)
