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
  1: keyF19, 2: keyF20, 3: keyF21, 4: keyF22, 5: keyF23, 6: keyF24 
]

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
  prevKeyCount = i


template schTask(task: proc(elapsed: TimestampMicros), rateHz: int): untyped =
  SchedulerEntry(period: 1_000_000 div rateHz, taskProc: task, elapsed: 0)

var SchedulerTable = [
  schTask(blinkLedTask, 100),
  schTask(hidKeysTask, 100),
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

  initInPi55Pio()
  setLedColor(1, 0x07100000.Grbw)

proc main() =
  var prevTime: TimestampMicros = 0
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

setup()
main()