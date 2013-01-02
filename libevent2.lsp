;; @module Libevent
;; @description Low-level newlisp bindings for libevent2.
;; @version 0.1
;; @author Jeff Ober <jeffober@gmail.com>

(define EventCB:EventCB)
(define EventID:EventID)

(context 'Libevent)

;-------------------------------------------------------------------------------
; Constants (from event.h)
;-------------------------------------------------------------------------------
(constant 'TIMEOUT 0x01)
(constant 'READ    0x02)
(constant 'WRITE   0x04)
(constant 'SIGNAL  0x08)
(constant 'PERSIST 0x10)

(constant 'EVENT_TYPES (list TIMEOUT READ WRITE SIGNAL PERSIST))
(constant 'EVENT_ALL   (apply '| EVENT_TYPES))

;-------------------------------------------------------------------------------
; Locate libevent library
;-------------------------------------------------------------------------------
(constant 'LIB
  (cond
    ((= ostype "Win32") "libevent.dll")
    ((= ostype "OSX")   "libevent.dylib")
    (true               "libevent.so")))

(unless (import LIB)
  (throw-error "libevent not found"))

;-------------------------------------------------------------------------------
; Import libevent routines
;-------------------------------------------------------------------------------
(import LIB "event_enable_debug_mode")
(import LIB "event_base_new")
(import LIB "event_base_free")
(import LIB "event_base_dispatch")
(import LIB "event_base_loopbreak")
(import LIB "event_new")
(import LIB "event_free")
(import LIB "event_add")
(import LIB "event_del")

(when MAIN:LIBEVENT2_DEBUG
  (event_enable_debug_mode))

;-------------------------------------------------------------------------------
; Loop control
;-------------------------------------------------------------------------------
(setf BASE nil)
(setf RUNNING nil)

;; @syntax (init)
;; Initializes the event loop. Will not re-init a previously initialized
;; loop unless <cleanup> is called first.
(define (init)
  (or BASE
      (not (zero? (setf BASE (event_base_new))))
      (throw-error "Error initializing event loop")))

(define (assert-initialized)
  (or BASE (throw-error "Event loop is not initialized")))

(define (cleanup)
  "Cleans up memory used by the event loop."
  (when RUNNING (stop))
  (when BASE
    (event_base_free BASE)
    (setf BASE nil)))

;; @syntax (run)
;; Starts the event loop. Does not return until the loop is stopped.
(define (run)
  (setf RUNNING true)
  (case (event_base_dispatch BASE)
    (0  true)
    (1  (throw-error "No more events registered."))
    (-1 (throw-error "Unable to start loop."))))

;; @syntax (stop)
;; Halts the event loop after the next iteration.
(define (stop)
  (unless (zero? (event_base_loopbreak BASE))
    (throw-error "Unable to halt event loop."))
  (setf RUNNING nil)
  (cleanup))

;-------------------------------------------------------------------------------
; Event callback triggering
;-------------------------------------------------------------------------------
(setf _id 0)
(define (event-id)
  (string "ev-" (inc _id)))

(define (trigger fd ev arg , id event cb)
  (setf id (get-string arg))
  (map set '(event cb) (EventCB id))
  (cb fd ev id)
  0)

(setf _event_cb (callback 'trigger "void" "int" "short int" "void*"))

;-------------------------------------------------------------------------------
; Event registration
;-------------------------------------------------------------------------------
;; @syntax (watch <fd> <ev> <cb>)
;; @param <int> 'fd' An open file descriptor
;; @param <int> 'ev' A bitmask of event constants
;; @param <fn>  'cb' A callback function
;; @return <int> id used to manage the event watcher
;; Registers callback function <cb> to be called whenever an event masked in
;; <ev> is triggered for <fd>. <cb> is called with the file descriptor,
;; event, and id as its arguments.
;;
;; @example
;; (watch socket (| READ WRITE)
;;   (fn (fd e)
;;     (cond
;;       (== e READ) (...)
;;       (== e WRITE) (...))))
(define (watch fd ev cb once , id event)
  (assert-initialized)

  (setf id (event-id))
  (EventID id id) ; anchor in memory

  (unless once
    (setf ev (| ev PERSIST)))

  (setf event (event_new BASE fd ev _event_cb (address (EventID id))))
  (EventCB id (list event cb))

  (unless (zero? (event_add event 0))
    (throw-error "Error adding event watcher."))

  id)

;; @syntax (unwatch <id>)
;; @param <int> 'id' ID returned by <watch>
;; Unregisters an event watcher. Once unwatched, the watcher id is invalid
;; and may no longer be used.
;;
;; @example
;; (watch socket WRITE
;;   (lambda (fd e id)
;;     (unwatch id)
;;     (write fd "Hello world")))
(define (unwatch id , event cb)
  (assert-initialized)
  (map set '(event cb) (EventCB id))
  (event_del event)
  (event_free event))

;; @syntax (once <fd> <ev> <cb>)
;; @param <int> 'fd' An open file descriptor
;; @param <int> 'ev' A bitmask of event constants
;; @param <fn>  'cb' A callback function
;; Registers a callback <cb> for events <ev> on descriptor <fd>. After the
;; callback is triggered, it is automatically unregistered for events <ev>.
;; For example, the example code from <unwatch> could be rewritten as:
;;
;; @example
;; (once socket WRITE
;;   (lambda (fd e)
;;     (write fd "Hello world")))
(define (once fd ev cb)
  (watch fd ev cb true))

(context 'MAIN)

