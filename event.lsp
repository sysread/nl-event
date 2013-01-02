(define EventCB:EventCB)

(context 'Event)

;-------------------------------------------------------------------------------
; Constants (from event.h)
;-------------------------------------------------------------------------------
(constant 'TIMEOUT 0x01)
(constant 'READ 0x02)
(constant 'WRITE 0x04)
(constant 'SIGNAL 0x08)
(constant 'PERSIST 0x10)
(constant 'EVENT_TYPES (list TIMEOUT READ WRITE SIGNAL PERSIST))
(constant 'EVENT_ALL (apply '| EVENT_TYPES))

;-------------------------------------------------------------------------------
; Locate libevent library
;-------------------------------------------------------------------------------
(constant 'LIB
  (cond
    ((= ostype "Win32") "libevent.dll")
    ((= ostype "OSX") "libevent.dylib")
    (true "libevent.so")))

(unless (import LIB)
  (throw-error "libevent not found"))

;-------------------------------------------------------------------------------
; Import libevent routines
;-------------------------------------------------------------------------------
(import LIB "event_base_new")
(import LIB "event_base_free")
(import LIB "event_base_loop")
(import LIB "event_base_loopexit")
(import LIB "event_base_loopbreak")

;-------------------------------------------------------------------------------
; Utilities
;-------------------------------------------------------------------------------
(define (do-events ev f)
  "Applies lambda f to all events masked in ev."
  (dolist (e EVENT_TYPES)
    (unless (zero? (& ev e))
      (f e))))

;-------------------------------------------------------------------------------
; Loop control
;-------------------------------------------------------------------------------
(setf BASE nil)
(setf RUNNING nil)

(define (init)
  "Performs initialization of the event loop. Throws an error if unable to init
  the loop."
  (or BASE
      (setf BASE (event_base_new))
      (throw-error "Error initializing event loop")))

(define (cleanup)
  "Cleans up memory used by the event loop."
  ;; shut down running loops
  (when RUNNING
    (halt)
    (setf RUNNING nil))

  ;; free and clean event base
  (when BASE
    (event_base_free BASE)
    (setf BASE nil))
  
  ;; empty registry
  (delete 'EventCB))

(define (loop)
  "Starts the event loop. This function will not return until `stop` is
  called."
  (setf RUNNING true)
  (event_base_loop BASE))

(define (stop)
  "Stops the event loop."
  (event_base_loopexit BASE)
  (cleanup))

(define (kill)
  "Breaks the event loop immediately."
  (event_base_loopbreak BASE)
  (event_base_loopexit BASE)
  (cleanup))

;-------------------------------------------------------------------------------
; Event registration
;-------------------------------------------------------------------------------
(define (cb-key fd e)
  "Generates a string key used to store a callback by file descriptor and
  event."
  (join (list fd e) "-"))

(define (cb-register ev cb)
  "Registers cb to be called when fd triggers an event in event mask ev."
  (do-events ev (fn (e) (EventCB (cb-key fd e) cb))))

(define (cb-trigger fd ev , cb)
  "Triggers callbacks for a file descriptor or events masked ev."
  (do-events ev
    (fn (e)
      (when (setf cb (EventCB (cb-key fd e)))
        (cb fd e)))))

(define (cb-clear fd)
  (do-events EVENT_ALL (fn (e) (EventCB (cb-key fd e) nil))))

;-------------------------------------------------------------------------------
; Event registration
;-------------------------------------------------------------------------------
(define (watch fd ev cb)
  )

(context 'MAIN)

