(context 'Event)

;;; Constants (from event.h)
(constant 'TIMEOUT 0x01)
(constant 'READ 0x02)
(constant 'WRITE 0x04)
(constant 'SIGNAL 0x08)
(constant 'PERSIST 0x10)


;;; Locate libevent library
(constant 'LIB
  (cond
    ((= ostype "Win32") "libevent.dll")
    ((= ostype "OSX") "libevent.dylib")
    (true "libevent.so")))

(unless (import LIB)
  (throw-error "libevent not found"))


;;; Import libevent routines
(import LIB "libevent_base_new")
(import LIB "libevent_base_free")
(import LIB "libevent_base_loop")
(import LIB "libevent_base_loop_break")
(import LIB "libevent_base_loop_exit")


;;; Loop control
(setf BASE 0)
(setf RUNNING nil)

(define (init)
  "Performs initialization of the event loop. Throws an error if unable to init
  the loop."
  (cleanup)
  (or BASE
      (setf BASE (libevent_base_new))
      (throw-error "Error initializing event loop")))

(define (cleanup)
  "Cleans up memory used by the event loop."
  (when RUNNING
    (halt)
    (setf RUNNING nil))

  (when BASE
    (libevent_base_free BASE)
    (setf BASE 0)))

(define (loop)
  "Starts the event loop. This function will not return until `stop` is
  called."
  (setf RUNNING true)
  (libevent_base_loop BASE))

(define (stop)
  "Stops the event loop."
  (libevent_base_exit BASE)
  (cleanup))

(define (halt)
  "Breaks the event loop immediately."
  (libevent_base_break BASE)
  (libevent_base_stop BASE)
  (cleanup))


;;; Event monitoring


(context 'MAIN)
