cmake_minimum_required(VERSION 3.20)
project(HorizonMessageBus LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(HorizonMessageBus SHARED
    HorizonMessageBus.cpp
    HorizonMessageBus.h
    constants/Limits.h
    entities/Message.h
    helpers/RingBuffer.h
    services/ChannelManager.h
    services/ServiceRegistry.h
)

target_compile_definitions(HorizonMessageBus PRIVATE HORIZON_MB_EXPORTS)

if(MSVC)
    target_compile_options(HorizonMessageBus PRIVATE /W4 /O2)
elseif(MINGW)
    target_link_options(HorizonMessageBus PRIVATE -static-libgcc -static-libstdc++ -static)
    target_link_libraries(HorizonMessageBus PRIVATE -lwinpthread)
endif()

set_target_properties(HorizonMessageBus PROPERTIES
    OUTPUT_NAME "HorizonMessageBus"
    PREFIX ""
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

install(TARGETS HorizonMessageBus
    RUNTIME DESTINATION lib
    LIBRARY DESTINATION lib
)
