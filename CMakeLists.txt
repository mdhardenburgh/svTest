cmake_minimum_required(VERSION 3.23.1)
project(svTest VERSION 1.0)
add_library(${PROJECT_NAME} INTERFACE)
target_sources(${PROJECT_NAME} INTERFACE testFramework.sv)