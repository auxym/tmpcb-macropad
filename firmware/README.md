# Nim Firmware for TMPCB macropad

## Building

Install the following by following their respective instructions:

[Nim](https://nim-lang.org/install.html)

[pico-sdk](https://github.com/raspberrypi/pico-sdk)

Install the [picostdlib](https://github.com/beef331/picostdlib) library, which
provides Nim bindings to pico-sdk:

`nimble install https://github.com/beef331/picostdlib`

Prepare the project for building against the pico-sdk installation (replace
the path with your clone of pico-sdk):

`piconim setup --sdk:/home/francis/pico-sdk`

Build:

`piconim build firmware.nim`

The `uf2` file for flashing will be found in the `csource/build` subdirectory.
