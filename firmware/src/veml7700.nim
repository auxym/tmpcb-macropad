import picostdlib/[gpio, i2c]
var vemli2c = i2c0

const
  VemlAddress = 0x10'u8

type IntegrationTime* {.pure.} = enum
  ms100 = 0b0000,
  ms200 = 0b0001,
  ms400 = 0b0010,
  ms800 = 0b0011,
  ms50 = 0b1000,
  ms25 = 0b1100

type Sensitivity* {.pure.} = enum
  s1x = 0,
  s2x = 1,
  div8 = 2,
  div4 = 3

proc vemlWrite(command: 0'u8..6'u8, data: uint16, noStop: bool) =
  var d: array[3, uint8]
  d[0] = command
  d[1] = data.uint8
  d[2] = (data shr 8).uint8
  vemli2c.writeBlocking(VemlAddress, d[0].addr, d.len.uint, noStop=noStop)

proc vemlConfig*(
    sensitivity: Sensitivity,
    itime: IntegrationTime,
    persist: 0..3,
    enableInterrupt: bool,
    shutDown: bool) =

  var val: uint16
  val = val or (sensitivity.uint16 shl 11)
  val = val or (itime.uint16 shl 6)
  val = val or (persist.uint16 shl 4)
  val = val or (enableInterrupt.uint16 shl 1)
  val = val or (shutDown.uint16)
  vemlWrite(0, val, false)

proc initVeml*() =
  # Fix hw bug, these pins are wrongly wired
  for pin in [26.Gpio, 27.Gpio]:
    pin.init()
    pin.disablePulls()

  setupI2c(vemli2c, psda=16.Gpio, pscl=17.Gpio, freq=100_000, pull=false)

proc vemlRead*(): uint16 =
  var
    cmd = 4
    data: array[2, uint8]

  vemli2c.writeBlocking(VemlAddress, cmd.addr, 1, noStop=true)
  discard vemli2c.readBlocking(
    VemlAddress, dest=data[0].addr, size=data.len.uint, noStop=false
  )
  result = data[0]
  result = result or data[1].uint16 shl 8
