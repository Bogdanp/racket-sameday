#lang racket/base

(require gregor
         (prefix-in http: net/http-easy)
         racket/contract
         racket/format
         "client.rkt"
         "view.rkt")

(provide
 (contract-out
  [current-client-root (parameter/c string?)]
  [current-client (parameter/c client?)]
  [make-client (-> #:username string? #:password string? client?)]
  [client? (-> any/c boolean?)]
  [call-with-awb-pdf (->* (string? (-> input-port? any))
                          (#:type (or/c 'A4 'A6)
                           #:client client?)
                          any)]
  [create-awb! (->* (recipient?
                     #:service-id exact-positive-integer?
                     #:pickup-point-id exact-positive-integer?
                     #:contact-person-id exact-positive-integer?)
                    (#:package-type package-type/c
                     #:parcel-dimensions (listof parcel-dimensions?)
                     #:insured-value cents/c
                     #:cod-amount cents/c
                     #:client client?
                     #:estimate? boolean?)
                    (or/c awb? awb-estimate?))]
  [delete-awb! (->* (string?) (client?) void?)]
  [get-awb-status (->* (string?) (client?) awb-status?)]
  [get-counties (->* ()
                     (string?
                      #:page exact-positive-integer?
                      #:per-page exact-positive-integer?
                      #:client client?)
                     (page/c (listof county?)))]
  [get-cities (->* ()
                   (string?
                    #:county-id exact-nonnegative-integer?
                    #:postal-code string?
                    #:page exact-positive-integer?
                    #:per-page exact-positive-integer?
                    #:client client?)
                   (page/c (listof city?)))]
  [get-pickup-points (->* () (client?) (page/c (listof pickup-point?)))]
  [get-services (->* () (client?) (page/c (listof service?)))]))


;; common data types ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(provide
 cents/c
 package-type/c
 page/c)

(define cents/c
  (and/c exact-integer? (>=/c 100)))

(define package-type/c
  (or/c 'parcel 'envelope 'large))

(define ((page/c p) v)
  (and (page? v)
       (p (page-data v))))

(json-view
 page
 (data
  pages
  [(current currentPage)]
  per-page
  total))

(json-view
 county
 (id name code))

(json-view
 city
 (id
  name
  county
  village
  postal-code
  logistic-circle
  [(delivery-agency samedayDeliveryAgency)]
  [(pickup-agency samedayPickupAgency)]
  [(extra-km extraKM)]))

(json-view
 contact
 (id
  name
  [(phone-number phone)]
  [(default? defaultContactPerson)]))


;; awbs ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(json-view
 recipient
 ([(city-id city)]
  [(county-id county)]
  address
  name
  phone
  email))

(json-view
 awb
 ([(number awbNumber)]
  [cost #:reader number->cents #:writer pp-cents]
  parcels))

(json-view
 awb-estimate
 ([amount #:reader number->cents #:writer pp-cents]
  currency))

(json-view
 awb-status
 ([(parcels parcelsStatus)]
  [(history expeditionHistory)]
  [(summary expeditionSummary)]
  [(expedition expeditionStatus)]))

(json-view
 expedition-history
 (status-id
  status
  status-label
  status-state
  [status-date #:reader iso8601->moment #:writer moment->iso8601]
  county
  reason
  transit-location))

(json-view
 expedition
 (status-id
  status
  status-label
  status-state
  [status-date #:reader iso8601->moment #:writer moment->iso8601]
  county
  reason
  transit-location))

(json-view
 expedition-summary
 (delivered?
  canceled?
  awb-number
  awb-weight
  service-payment
  cash-on-delivery?
  redirection-attempts
  delivery-attempts
  delivered-at))

(json-view
 parcel
 (status-id
  status
  status-label
  status-state
  [status-date #:reader iso8601->moment #:writer moment->iso8601]
  county
  reason
  transit-location
  [(awb parcelAwbNumber)]
  [(details parcelDetails)]
  [(returning? inReturn)]))

(json-view
 parcel-dimensions
 (weight
  width
  height
  length))

(define (package-type-id t)
  (case t
    [(parcel) 0]
    [(envelope) 1]
    [(large) 2]))

(define (create-awb! recipient
                     #:service-id service-id
                     #:pickup-point-id pickup-point-id
                     #:contact-person-id contact-person-id
                     #:package-type [package-type 'parcel]
                     #:parcel-dimensions [parcel-dimensions null]
                     #:insured-value [insured-value 0]
                     #:cod-amount [cod-amount 0]
                     #:reference [reference #f]
                     #:estimate? [estimate? #f]
                     #:client [c (current-client)])
  (define weight
    (for/sum ([dim (in-list parcel-dimensions)])
      (parcel-dimensions-weight dim)))
  (define fields
    `((service . ,(~a service-id))
      (pickupPoint . ,(~a pickup-point-id))
      (thirdPartyPickup . "0")
      (contactPerson . ,(~a contact-person-id))
      (packageType . ,(~a (package-type-id package-type)))
      (packageNumber . ,(~a (length parcel-dimensions)))
      (packageWeight . ,(~a weight))
      (cashOnDelivery . ,(pp-cents cod-amount))
      (insuredValue . ,(pp-cents insured-value))
      (awbPayment . "1") ;; client
      (awbRecipient . ,recipient)
      (parcels . ,parcel-dimensions)
      (clientInternalReference . ,reference)))
  (define endpoint
    (if estimate?
        "/api/awb/estimate-cost"
        "/api/awb"))
  (post c endpoint #:form (arraify fields)))

(define (delete-awb! awb [c (current-client)])
  (void (delete c (~a "/api/awb/" awb))))

(define (call-with-awb-pdf awb f
                           #:type [type 'A6]
                           #:client [c (current-client)])
  (define res #f)
  (dynamic-wind
    (lambda ()
      (set! res (get c (~a "/api/awb/download/" awb "/" type) #:stream? #t)))
    (lambda ()
      (f (http:response-output res)))
    (lambda ()
      (http:response-close! res))))

(define (get-awb-status awb [c (current-client)])
  (get c (~a "/api/client/awb/" awb "/status")))


;; counties & cities ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (get-counties [name #f]
                      #:page [page 1]
                      #:per-page [per-page 100]
                      #:client [c (current-client)])
  (define params
    (filter cdr `((name . ,name)
                  (page . ,(~a page))
                  (countPerPage . ,(~a per-page)))))
  (get c "/api/geolocation/county" #:params params))

(define (get-cities [name #f]
                    #:county-id [county-id #f]
                    #:postal-code [postal-code #f]
                    #:page [page 1]
                    #:per-page [per-page 100]
                    #:client [c (current-client)])
  (define params
    (filter cdr `((name . ,name)
                  (county . ,(maybe-~a county-id))
                  (postalCode . ,postal-code)
                  (page . ,(~a page))
                  (countPerPage . ,(~a per-page)))))
  (get c "/api/geolocation/city" #:params params))


;; pickup points ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(json-view
 pickup-point
 (id
  [(county-id county)]
  [(city-id city)]
  address
  [(default? defaultPickupPoint)]
  [(contacts pickupPointContactPerson)]
  alias))

(define (get-pickup-points [c (current-client)])
  (get c "/api/client/pickup-points"))


;; services ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(json-view delivery-type (id name))

(json-view
 service
 (id
  name
  [(type deliveryType)]
  [(code serviceCode)]
  [(default? defaultServices)]))

(define (get-services [c (current-client)])
  (get c "/api/client/services"))


;; help ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (maybe-~a v)
  (and v (~a v)))

(define (number->cents v)
  (inexact->exact (round (* v 100))))

(define (pp-cents v)
  (~r (/ v 100) #:precision '(= 2)))

(define (arraify params)
  (define (help k v)
    (cond
      [(not v) null]

      [(hash? v)
       (for/list ([(s-k s-v) (in-hash v)] #:when s-v)
         (cons (string->symbol (format "~a[~a]" k s-k)) (~a s-v)))]

      [(list? v)
       (for/fold ([res null])
                 ([x (in-list v)]
                  [i (in-naturals)])
         (append (help (string->symbol (format "~a[~a]" k i)) x) res))]

      [else
       (list (cons k (~a v)))]))

  (for/fold ([res null])
            ([p (in-list params)])
    (append (help (car p) (cdr p)) res)))

(module+ test
  (require rackunit)

  (test-case "handles nested data"
    (check-equal?
     (sort
      #:key car
      (arraify
       `((a . 1)
         (b . 2)
         (c . (1 2 3))
         (d . ,(list
                (hasheq 'a "d0a" 'b "d0b")
                (hasheq 'a "d1a" 'b "d1b")))))
      symbol<?)
     (sort
      #:key car
      `((a . "1")
        (b . "2")
        (|c[0]| . "1")
        (|c[1]| . "2")
        (|c[2]| . "3")
        (|d[0][a]| . "d0a")
        (|d[0][b]| . "d0b")
        (|d[1][a]| . "d1a")
        (|d[1][b]| . "d1b"))
      symbol<?)))

  (test-case "skips false hash fields"
    (check-equal?
     (arraify
      `((a . ,(parcel-dimensions #:weight 10))))
     `((|a[weight]| . "10")))))
