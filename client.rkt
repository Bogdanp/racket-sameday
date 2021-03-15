#lang racket/base

(require (for-syntax racket/base)
         gregor
         (prefix-in http: net/http-easy)
         racket/format
         racket/match
         syntax/parse/define)

(define-logger sameday)

;; errors ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(provide
 exn:fail:sameday?)

(struct exn:fail:sameday exn:fail ())


;; root ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(provide
 current-client-root
 current-client)

(define current-client-root
  (make-parameter "https://api.sameday.ro"))

(define current-client
  (make-parameter #f))


;; token ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(struct token (sema [expires-at #:mutable] [str #:mutable]))

(define (make-expired-token)
  (token (make-semaphore 1) (current-seconds) #f))

(define (token-expired? t)
  (<= (token-expires-at t) (current-seconds)))

(define (token-refresh! t s username password)
  (call-with-semaphore (token-sema t)
    (lambda ()
      (when (token-expired? t)
        (parameterize ([http:current-session s])
          (log-sameday-debug "refreshing authentication token")
          (define resp
            (http:post (~a (current-client-root) "/api/authenticate")
                       #:headers (hasheq
                                  'x-auth-username username
                                  'x-auth-password password)))
          (match resp
            [(http:response #:status-code 200)
             (define j (http:response-json resp))
             (define exp
               (parse-expiration-time (hash-ref j 'expire_at)))
             (set-token-expires-at! t (->posix exp))
             (set-token-str! t (hash-ref j 'token))]

            [(http:response #:status-code code)
             (oops "authentication failed~n  status code: ~a~n  response: ~s" code (http:response-body resp))]))))))

(define (oops msg . args)
  (raise (exn:fail:sameday
          (apply format msg args)
          (current-continuation-marks))))

(define (parse-expiration-time s)
  (parameterize ([current-locale "ro"]
                 [current-timezone "Europe/Bucharest"])
    (parse-moment s "yyyy-MM-dd HH:mm")))


;; client ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(provide
 make-client
 client?)

(struct client (session username password token))

(define (make-client #:username username
                     #:password password)
  (client (http:make-session) username password (make-expired-token)))

(define ((client-auth c) _url headers params)
  (match-define (client session username password t) c)
  (when (token-expired? t)
    (token-refresh! t session username password))
  (values (hash-set headers 'x-auth-token (token-str t)) params))

(define client-request
  (make-keyword-procedure
   (lambda (kws kw-args c path . args)
     (define uri (~a (current-client-root) path))
     (log-sameday-debug "requesting ~e" uri)
     (define resp
       (keyword-apply http:session-request
                      kws kw-args
                      (client-session c)
                      uri
                      args))

     (when (>= (http:response-status-code resp) 400)
       (oops "request failed~n  status code: ~a~n  body: ~s"
             (http:response-status-code resp)
             (http:response-body resp)))

     (match (http:response-headers-ref resp 'content-type)
       [(regexp #rx"application/json")
        (http:response-json resp)]
       [_
        resp]))))

(define-syntax-parser define-requesters
  [(_ id:id ...)
   #'(begin
       (provide id ...)
       (define id
         (make-keyword-procedure
          (lambda (kws kw-args c . args)
            (keyword-apply client-request kws kw-args c args #:method 'id #:auth (client-auth c))))) ...)])

(define-requesters
  delete get patch post put)
