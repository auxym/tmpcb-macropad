import picostdlib/[pio, gpio, clock]

let inst = pio0

const
  NumLeds = 3
  DataPin = 1.Gpio
  Sm = 0.PioStateMachine
  BitRate = 800_000

type
  LedIndex* = range[0 .. (NumLeds - 1)]
  Grbw* = distinct uint32

var ledState: array[LedIndex, Grbw]

{.push header: "inpi55.pio.h".}
proc inpi55_program_get_default_config(offset: uint): PioSmConfig {.importc.}

let
  inpi55_T1 {.importc.}: int 
  inpi55_T2 {.importc.}: int 
  inpi55_T3 {.importc.}: int 

  inpi55_program {.importc.}: PioProgram
{.pop.}

proc initInPi55Pio*() =
  inst.claim(Sm)
  inst.gpioInit DataPin
  inst.setPinDirs(Sm, Out, {DataPin})

  let offset = inst.addProgram(inpi55_program)

  var cfg = inpi55_program_get_default_config(offset)
  cfg.setSidesetPins(DataPin)
  cfg.setOutShift(shiftRight=false, autopull=true, pullThreshold=32)
  cfg.setFifoJoin(PioFifoJoin.tx)

  let
    cyclesPerBit = inpi55_T1 + inpi55_T2 + inpi55_T3
    clockdiv = getHz(ClockIndex.sys).float / (BitRate * cyclesPerBit.float)
  cfg.setClkdiv clockdiv

  inst.init(Sm, offset, cfg)
  inst.enable Sm

proc put(r, g, b, w: uint8) =
  var val: uint32 = w or (b.uint32 shl 8) or (r.uint32 shl 16) or (g.uint32 shl 24)
  inst.putBlocking(Sm, val)

proc put(grbw: Grbw) =
  inst.putBlocking(Sm, grbw.uint32)

proc setLedColor*(led: LedIndex, color: Grbw) =
  ledState[led] = color
  for c in ledState: put c
