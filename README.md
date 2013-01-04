nl-event
================================================================================

The libevent module provides a wrapper on top of the [libevent2
library](http://libevent.org/).

Todo
--------------------------------------------------------------------------------
  * signals


Summary
--------------------------------------------------------------------------------
    @example
    ; --------------------------------------------------------------------------
    ; Timers
    ; --------------------------------------------------------------------------
    (libevent:init)

    (libevent:set-interval 10
      (fn () (println "Another 10ms have passed!")))

    (libevent:run)


    ; --------------------------------------------------------------------------
    ; IO
    ; --------------------------------------------------------------------------
    (libevent:init)
    (setf socket (net-connect "www.google.com" 80))
    (setf buffer "")

    ; Wait until socket is write-ready
    (libevent:watch-once socket libevent:WRITE
      (fn (fd e id)
        ; send HTTP request
        (write socket "GET / HTTP/1.0\r\n\r\n")

        ; wait for response
        (libevent:watch socket libevent:READ
          (fn (fd e id , buf bytes)
            ; read to local buffer
            (setf bytes (read fd buf 4096))
            (if bytes
              ; write to global buffer
              (write buffer buf)
              ; kill watcher and stop loop
              (begin
                (libevent:unwatch id)
                (libevent:stop)))))))

    (libevent:run)
    (println buffer)


    ; --------------------------------------------------------------------------
    ; Using buffers
    ; --------------------------------------------------------------------------
    (libevent:init)
    
    (setf html "")
    
    (define (on-read data)
      (write html data))
    
    (define (on-event ev data)
      (cond
        ((libevent:masks? ev libevent:BUFFER_EOF)
         (write html data)
         (println "Disconnected")
         (libevent:stop))
        ((libevent:masks? ev libevent:BUFFER_ERROR)
         (println "An error occurred")
         (libevent:stop))
        ((libevent:masks? ev libevent:BUFFER_TIMEOUT)
         (println "Timed out")
         (libevent:stop))))
    
    (or (setf socket (net-connect "www.google.com" 80))
        (throw-error "Unable to connect"))
    
    (setf buffer (libevent:make-buffer socket (regex-comp "[\r\n]+" 4) on-read on-event))
    (libevent:buffer-send buffer "GET / HTTP/1.0\r\n\r\n")
    (libevent:run)
    
    (println html)

