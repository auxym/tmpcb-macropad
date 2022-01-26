import picostdlib/[pio, gpio, clock]

{.push header: "inpi55.pio.h".}
proc inpi55_program_get_default_config(offset: uint): PioSmConfig {.importc.}

let
  inpi55_T1 {.importc.}: int 
  inpi55_T2 {.importc.}: int 
  inpi55_T3 {.importc.}: int 

  inpi55_program* {.importc.}: PioProgram
{.pop.}

proc initInPi55Pio*(
    pioIns: PioInstance, sm: PioStateMachine, offset: uint, pin: Gpio
    ) =
  pioIns.gpioInit pin
  pioIns.setConsecutivePindirs(sm, pin, 1, true)

  var cfg = inpi55_program_get_default_config(offset)
  cfg.setSidesetPins(pin)
  cfg.setOutShift(false, true, 32)
  cfg.setFifoJoin(PioFifoJoin.tx)

  # Per IN-PI55 datasheet
  const inpi55Freq = 800_000 # Hz

  let
    cyclesPerBit = inpi55_T1 + inpi55_T2 + inpi55_T3
    clockdiv = getHz(ClockIndex.sys).float / (inpi55Freq * cyclesPerBit.float)
  cfg.setClkdiv clockdiv

  pioIns.init(sm, offset, cfg)
  pioIns.enable sm

proc inPi55Put*(pioIns: PioInstance, sm: PioStateMachine,
    r: uint8, g: uint8, b: uint8, w: uint8) =
  var val: uint32 = w or (b.uint32 shl 8) or (r.uint32 shl 16) or (g.uint32 shl 24)
  pioIns.putBlocking(sm, val)
