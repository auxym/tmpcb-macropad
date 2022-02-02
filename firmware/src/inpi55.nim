import picostdlib/[pio, gpio, clock]
import std/math

let inst = pio0

const
  NumLeds = 3
  DataPin = 1.Gpio
  Sm = 0.PioStateMachine
  BitRate = 800_000

type
  LedIndex* = range[0 .. (NumLeds - 1)]

type LedColor {.packed.} = object
  white, blue, red, green: uint8

var ledState: array[LedIndex, LedColor]

func toUint32(c: LedColor): uint32 =
  cast[uint32](c)

func toUint32(c: LedColor, brightnessDiv: 1..255): uint32 =
  let x = LedColor(
    red: c.red div brightnessDiv.uint8,
    green: c.green div brightnessDiv.uint8,
    blue: c.blue div brightnessDiv.uint8,
    white: c.white div brightnessDiv.uint8
  )
  cast[uint32](x)

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

proc put(c: LedColor) =
  inst.putBlocking(Sm, c.toUint32)

proc put(c: uint32) =
  inst.putBlocking(Sm, c)

proc setLedColor*(led: LedIndex, color: LedColor) =
  ledState[led] = color
  for c in ledState: put c

proc createRainbowTable(): seq[LedColor] {.compileTime.} =
  ## Create a look-up table of RGB rainbow colors, evaluated at compile time
  ## Based on "sine wave" algorithm from:
  ## https://www.instructables.com/How-to-Make-Proper-Rainbow-and-Random-Colors-With-/
  const
    maxAngle = 3.0 * PI
    numSteps = 100
    angleStep = maxAngle / numSteps
    twoPi = 2 * PI

  # convert the range -1.0 .. 1.0 to 0 .. 255
  proc trig2byte(x: float): uint8 = ((1.0 + x) * 127.5).toInt.uint8

  result = newSeq[LedColor](numSteps)
  for i in 0 ..< numSteps:
    let angle = angleStep * i.float
    if angle <= PI:
      result[i].red = cos(angle).trig2byte
      result[i].green = (-cos(angle)).trig2byte
      result[i].blue = 0
    elif angle <= twoPi:
      result[i].red = 0
      result[i].green = (-cos(angle)).trig2byte
      result[i].blue = cos(angle).trig2byte
    else:
      result[i].red = (-cos(angle)).trig2byte
      result[i].green = 0
      result[i].blue = cos(angle).trig2byte

const ColorTable = createRainbowTable()

proc nextRainbowColor*() =
  var i {.global.} = 0

  const colorOffset = max(1, ColorTable.len div NumLeds)

  for j in 0 ..< NumLeds:
    let
      colorIndex = (i + (colorOffset * j)) mod ColorTable.len
      color = ColorTable[colorIndex]

    put(color.toUint32(16))

  i.inc
  if i > ColorTable.high: i = 0
