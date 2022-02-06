cmake_minimum_required(VERSION 3.13)

# initialize the SDK based on PICO_SDK_PATH

# note: this must happen before project()
include(pico_sdk_import.cmake)

project(firmware)

# initialize the Raspberry Pi Pico SDK
pico_sdk_init()

# add program file(s)
file(GLOB MyCSources *.c)
add_executable(firmware)

target_sources(firmware PUBLIC
        ${CMAKE_CURRENT_LIST_DIR}/../src/usb_descriptors.c
        ${MyCSources}
        )

# Make sure TinyUSB can find tusb_config.h
target_include_directories(firmware PUBLIC ${CMAKE_CURRENT_LIST_DIR}/../src)

# Compile PIO program for IN-PI55 LEDs
pico_generate_pio_header(firmware ${CMAKE_CURRENT_LIST_DIR}/../src/inpi55.pio)

# pull in our pico_stdlib which pulls in commonly used features
# hardware_adc tinyusb_device tinyusb_board Currently supported.
target_link_libraries(firmware pico_stdlib hardware_adc tinyusb_board tinyusb_device hardware_pio hardware_i2c)

# enable usb output, disable uart output
pico_enable_stdio_usb(firmware 0)
pico_enable_stdio_uart(firmware 0)

# create map/bin/hex/uf2 file etc.
pico_add_extra_outputs(firmware)

# add url via pico_set_program_url
pico_set_program_url(firmware 1)
