import std/heapqueue
import picostdlib/time

const
  MaxPriority = 19

type
  Callback = proc() {.closure.}

  Priority = distinct range[0..MaxPriority]

  TaskIdImpl = int16

  TaskId* = distinct TaskIdImpl

  Task = object
    cb: Callback
    id: TaskId
    prio: Priority
    next, prev: TaskId

  Clock = uint64

  Timer = object
    timeout: Clock
    cb: Callback
    period: Clock

  Scheduler = object
    runqueue: array[Priority, TaskId]
    tasks: seq[Task]
    timers: HeapQueue[Timer] # TODO: custom fixed-size heap?

  EventQueue[T] = object
    task: TaskId
    events: seq[T]
    deferredEvents: seq[T]
    head, tail, len: int

const
  InvalidTask  = TaskId(-1)

template `<`(a, b: Timer): bool = a.timeout < b.timeout

proc `==`(a, b: TaskId): bool {.borrow.}
proc `<`(a, b: TaskId): bool {.borrow.}
template isValid(t: TaskId): bool = not (t < 0.TaskId)

proc `<`(a, b: Priority): bool {.borrow.}

var sch: Scheduler

template next(t: TaskId): TaskId = sch.tasks[t.int].next

proc insertBefore(this, before: TaskId) =
  # insert before in circular linked list
  let pprev = sch.tasks[before.int].prev
  sch.tasks[pprev.int].next = this
  sch.tasks[before.int].prev = this
  sch.tasks[this.int].next = before
  sch.tasks[this.int].prev = pprev

proc del(this: TaskId) =
  # unlink task from linked list
  let
    pnext = sch.tasks[this.int].next
    pprev = sch.tasks[this.int].prev
  if pnext == this:
    # Only item in list
    sch.tasks[this.int].next = InvalidTask
    sch.tasks[this.int].prev = InvalidTask
  else:
    sch.tasks[pnext.int].prev = pprev
    sch.tasks[pprev.int].next = pnext

proc signal*(t: TaskId) =
  let prio = sch.tasks[t.int].prio
  if isValid(sch.runqueue[prio]):
    insertBefore(t, sch.runqueue[prio])
  else:
    # Runqueue of this priority is empty
    sch.runqueue[prio] = t  
    sch.tasks[t.int].next = t
    sch.tasks[t.int].prev = t

proc wait*(t: TaskId) =
  if next(t) == t:
    # Only item in list
    let prio = sch.tasks[t.int].prio
    sch.runqueue[prio] = InvalidTask
  del t

proc runNextTask {.inline.} =
  for prio in Priority.low .. Priority.high:
    if isValid(sch.runqueue[prio]):
      sch.tasks[sch.runqueue[prio].int].cb()
      # Round robin priority-level runqueue
      sch.runqueue[prio] = next sch.runqueue[prio]
      return

proc checkTimers {.inline.} =
  let now = timeUs64()
  while sch.timers[0].timeout > now:
    let c = sch.timers[0]
    c.cb()
    if c.period > 0:
      var newTimer = c
      newTimer.timeout = c.timeout + c.period
      discard sch.timers.replace(newTimer)
    else:
      discard sch.timers.pop()

proc runScheduler*() =
  while true:
    checkTimers()
    runNextTask()

template cap(q: EventQueue): int = q.events.len

proc push*[T](q: EventQueue[T], e: T) =
  if q.len >= q.cap:
    # Queue is full. Panic? Block?
    # For now just drop the event
    return

  # Push at tail, pop from head
  q.events[q.tail] = e
  q.tail = (q.tail + 1) mod q.cap
  q.len.inc

  if q.len == 1:
    sch.signal(q.task)

proc pop*[T](q: EventQueue[T]): T =
  if q.len <= 0:
    raise newException(RangeDefect, "Queue is empty")

  # Push at tail, pop from head
  result = q.events[q.head]
  q.head = (q.head + 1) mod q.cap
  q.len.dec

  if q.len == 0:
    sch.wait(q.task)
