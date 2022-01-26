import picostdlib/[gpio, time, tusb, pio]
import usb_descriptors 
import inpi55

type TimestampMicros = uint64

type State = object
  ledBlinkInterval: uint64 # ms
  inPi55Sm: PioStateMachine
  inPiPioInit: bool

type SchedulerEntry = object
  period: TimestampMicros
  elapsed: TimestampMicros
  taskproc: proc(elapsed: TimestampMicros)

var state: State

const
  LedBlinkIntervalNotMounted = 250'u64
  LedBlinkIntervalMounted = 1000'u64
  LedBlinkIntervalSuspended = 2500'u64

  Switch1Pin = 3.Gpio
  Switch2Pin = 4.Gpio
  Switch3Pin = 5.Gpio
  Switch4Pin = 8.Gpio
  Switch5Pin = 7.Gpio
  Switch6Pin = 6.Gpio

  InPi55DataPin = 1.Gpio

  usbser = 0.UsbSerialInterface
  hid = 0.UsbHidInterface

let inPi55Pio = pio0

let hidKeyboardReportId
  {.importc: "REPORT_ID_KEYBOARD", header: "usb_descriptors.h".}: uint8

proc blinkLedTask(elapsed: TimestampMicros) =
  var nextChange {.global.} = state.ledBlinkInterval * 1000
  var ledState {.global.}: bool
  if nextChange > elapsed:
    nextChange = nextChange - elapsed
  else:
    DefaultLedPin.put (if ledState: Low else: High)
    ledState = not ledState
    nextChange = state.ledBlinkInterval * 1000

proc hidTask(elapsed: TimestampMicros) =
  if not hid.ready(): return

  var kbPress {.global.}: bool
  if Switch3Pin.get == Low:
    discard hid.sendKeyboardReport(hidKeyboardReportId, {}, keyA)
    kbPress = true
  else:
    if kbPress:
      # Need to send an empty report to tell host that key isn't pressed anymore
      discard hid.sendKeyboardReport(1, {})
      kbPress = false

proc cdcHelloTask(elapsed: TimestampMicros) =
  usbser.writeLine "Hello, world"

proc inPi55Put(r: uint8, g: uint8, b: uint8, w: uint8) =
  inPi55Pio.inPi55Put(state.inPi55Sm, g, r, b, w)

proc inpi55Task(elapsed: TimestampMicros) =
  inPi55Put(0, 30, 15, 0)
  inPi55Put(15, 0, 30, 0)
  inPi55Put(30, 15, 0, 0)

template schTask(task: proc(elapsed: TimestampMicros), rateHz: int): untyped =
  SchedulerEntry(period: 1_000_000 div rateHz, taskProc: task, elapsed: 0)

var SchedulerTable = [
  schTask(blinkLedTask, 100),
  schTask(hidTask, 100),
  schTask(cdcHelloTask, 1),
  schTask(inpi55Task, 1)
]

proc setup() =
  discard usbInit()
  boardInit()
  sleep 10

  state.ledBlinkInterval = LedBlinkIntervalNotMounted
  state.inPiPioInit = false

  DefaultLedPin.init()
  DefaultLedPin.setDir(Out)
  
  let keyswitches = [
    Switch1Pin,
    Switch2Pin,
    Switch3Pin,
    Switch3Pin,
    Switch4Pin,
    Switch5Pin,
    Switch6Pin,
  ]
  for ksw in keyswitches:
    ksw.init()
    ksw.disablePulls()

  # Init PIO program for IN-PI55 LEDs
  let
    inpi55ProgOffset = inPi55Pio.addProgram(inpi55_program)
    inpi55SmResult = inPi55Pio.claimUnusedSm(false)
  if inpi55SmResult >= 0:
    state.inPiPioInit = true
    state.inPi55Sm = inpi55SmResult.PioStateMachine
    inPi55Pio.initInPi55Pio(state.inpi55Sm, inpi55ProgOffset, InPi55DataPin)

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

hidGetReportCallback(instance, reportId, reportType, buffer, reqLen):
  discard

hidSetReportCallback(instance, reportId, reportType, buffer, reqLen):
  discard

mountCallback:
  state.ledBlinkInterval = LedBlinkIntervalMounted

unmountCallback:
  state.ledBlinkInterval = LedBlinkIntervalNotMounted

suspendCallback(wakeUpEnabled):
  state.ledBlinkInterval = LedBlinkIntervalSuspended

resumeCallback:
  state.ledBlinkInterval = LedBlinkIntervalMounted
