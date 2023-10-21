syn clear

syn match SimThreadId /Thread\s\({[^}]\{-}}\|\[[^\]]\{-}\]\)\(\.\d\+\|\.-\)\?/
syn match SimTVarId /TVarId\s\d\+/

syn keyword SimEvent
      \ Say
      \ Log
      \ Mask
      \ Throw
      \ ThrowTo
      \ ThrowToBlocked
      \ ThrowToWakeup
      \ ThrowToUnmasked
      \ ThreadUnhandled
      \ TxCommitted
      \ TxAborted
      \ TxBlocked
      \ TxWakeup
      \ Unblocked
      \ ThreadDelay
      \ ThreadDelayFired
      \ TimeoutCreated
      \ TimeoutFired
      \ RegisterDelayCreated
      \ RegisterDelayFired
      \ TimerCreated
      \ TimerUpdated
      \ TimerCancelled
      \ TimerFired
      \ ThreadStatus
      \ ThreadSleep
      \ ThreadWake
      \ Deschedule
      \ Reschedule

syn keyword SimEventThread
      \ ThreadUnhandled
      \ ThreadForked
      \ ThreadFinished
      \ MainException

syn keyword SimPOREvent
      \ FollowControl
      \ AwaitControl
      \ PerformAction
      \ Effect
      \ Races Races

syn keyword SimResult
      \ MainResult
syn keyword SimResultError
      \ MainException
      \ Deadlock
      \ Loop
      \ InternalError

syn match SimStart /Simulation trace with discovered schedules:/
syn keyword SimStart SimStart

hi link SimEvent Structure
hi link SimPOREvent Statement
hi link SimEventSay String
hi link SimThreadId Number
hi link SimTVarId Number
hi link SimEventThread SignColumn
hi link SimStart Title
hi link SimResult Title
hi link SimResultError Error
