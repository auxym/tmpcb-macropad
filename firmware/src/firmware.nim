import picostdlib/[gpio, time, tusb]
import usb
import inpi55

type TimestampMicros = uint64

type SchedulerEntry = object
  period: TimestampMicros
  elapsed: TimestampMicros
  taskproc: proc(elapsed: TimestampMicros)

type KeySwitch = range[1..6]

const SwitchTable: array[KeySwitch, Gpio] = [
  1: 3.Gpio, 2: 4.Gpio, 3: 5.Gpio, 4: 8.Gpio, 5: 7.Gpio, 6: 6.Gpio
]

const KeyMapFKeys: array[KeySwitch, KeyboardKeypress] = [
  1: keyF14, 2: keyF15, 3: keyF16, 4: keyF17, 5: keyF18, 6: keyF19
]

const
  REnc1A = 19.Gpio
  REnc1B = 20.Gpio
  REnc1Switch = 18.Gpio
  REnc2A = 13.Gpio
  REnc2B = 14.Gpio
  REnc2Switch = 15.Gpio

type
  REncChannel = enum chA, chB
  REncState = array[REncChannel, Value]

proc blinkLedTask(elapsed: TimestampMicros) =
  const blinkIntervalArr = [
    usbMounted: 1000,
    usbSuspended: 2500,
    usbUnmounted: 250,
  ]

  var
    nextChange {.global.}: TimestampMicros
    ledState {.global.}: bool

  if nextChange > elapsed:
    nextChange = nextChange - elapsed
  else:
    DefaultLedPin.put (if ledState: Low else: High)
    ledState = not ledState
    let blinkInterval = blinkIntervalArr[getUsbState()]
    nextChange = blinkInterval.uint64 * 1000

proc hidKeysTask(elapsed: TimestampMicros) =
  if not hid.ready: return

  var
    prevKeyCount {.global.}: Natural
    i = 0
    keyPresses: array[6, KeyboardKeypress]

  for (idx, pin) in SwitchTable.pairs:
    if pin.get == Low:
      keyPresses[i] = KeyMapFKeys[idx]
      inc i

  if i > 0 or prevKeyCount > 0:
    discard hid.sendKeyboardReport(keyboardReportId, {}, keyPresses)
    usbDeviceTask()
  prevKeyCount = i

proc `$`(v: Value): string = $v.int

proc encoderTask(elapsed: TimestampMicros) =
  var
    prevState {.global.}: REncState
    isInit {.global.} = false
  if not isInit:
    prevState = [REnc1A.get(), REnc1B.get()]
    isInit = true

  let curState: REncState = [REnc1A.get(), REnc1B.get()]

  if prevState[chA] == Low and curState[chA] == High:
    let val = if curState[chB] == High: 1'i8 else: -1'i8
    if hid.ready:
      discard hid.sendMouseReport(
        mouseReportId, buttons={}, x=0, y=0, horizontal=0, vertical=val
      )
    usbDeviceTask()

  prevState = curState

proc rgbTask(elapsed: TimestampMicros) =
  var remain {.global.}: TimestampMicros

  if remain > elapsed:
    remain = remain - elapsed
  else:
    remain = 40_000
    nextRainbowColor()

template schTask(task: proc(elapsed: TimestampMicros), rateHz: int): untyped =
  SchedulerEntry(period: 1_000_000 div rateHz, taskProc: task, elapsed: 0)

var SchedulerTable = [
  schTask(blinkLedTask, 100),
  schTask(hidKeysTask, 100),
  schTask(encoderTask, 400),
  schTask(rgbTask, 100),
]

proc setup() =
  discard usbInit()
  boardInit()
  sleep 10

  DefaultLedPin.init()
  DefaultLedPin.setDir(Out)

  for ksw in SwitchTable:
    ksw.init()
    ksw.disablePulls()

  for pin in [REnc1A, REnc1B, REnc1Switch, REnc2A, REnc2B, REnc2Switch]:
    pin.init()
    pin.disablePulls()

  initInPi55Pio()

proc main() =
  var
    prevTime: TimestampMicros = 0
    maxLoopTime: uint64
    loopCount: int
  while true:
    usbDeviceTask()

    let
      now = timeUs64()
      dt = now - prevTime
    for entry in SchedulerTable.mitems:
      if entry.elapsed > entry.period:
        entry.taskproc(entry.elapsed)
        entry.elapsed = 0
      entry.elapsed = entry.elapsed + dt
    prevTime = now

    # Main loop profiling
    when false:
      let mainLoopElapsed = timeUs64() - now
      maxLoopTime = max(maxLoopTime, mainLoopElapsed)
      loopCount.inc
      if loopCount == 100_000:
        usbser.writeLine("Loop: " & $maxLoopTime & " us")
        loopCount = 0
        maxLoopTime = 0

setup()
main()
