#lang racket

(require gregor
         (prefix-in http: net/http-easy)
         racket/contract
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
  [delete-awb! (->* (string?) (client?) void?)]
  [estimate-awb (->* (recipient?
                      #:service-id exact-positive-integer?
                      #:pickup-point-id exact-positive-integer?
                      #:contact-person-id exact-positive-integer?)
                     (#:package-type package-type/c
                      #:parcel-dimensions (listof parcel-dimensions?)
                      #:insured-value cents/c
                      #:cod-amount cents/c
                      #:client client?)
                     awb-estimate?)]
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
  (and exact-integer? (>=/c 100)))

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
  extra-km))

(json-view
 contact
 (id
  name
  phone-number
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
 awb-status
 ([(parcels parcelsStatus)]
  [(history expeditionHistory)]
  [(summary expeditionSummary)]
  [(expedition expeditionStatus)]))

(json-view
 awb-estimate
 (amount
  currency
  time))

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
  parcel-awb-number))

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

(define (delete-awb! awb [c (current-client)])
  (void (delete c (~a "/api/awb/" awb))))

(define (estimate-awb recipient
                      #:service-id service-id
                      #:pickup-point-id pickup-point-id
                      #:contact-person-id contact-person-id
                      #:package-type [package-type 'parcel]
                      #:parcel-dimensions [parcel-dimensions null]
                      #:insured-value [insured-value 0]
                      #:cod-amount [cod-amount 0]
                      #:client [c (current-client)])
  (define weight
    (for/sum ([dim (in-list parcel-dimensions)])
      (parcel-dimensions-weight dim)))
  (define fields
    `((service . ,(~a service-id))
      (pickupPoint . ,(~a pickup-point-id))
      (thirdPartyPickup . "0")
      (contactPerson . ,(maybe-~a contact-person-id))
      (packageType . ,(~a (package-type-id package-type)))
      (packageNumber . ,(~a (length parcel-dimensions)))
      (packageWeight . ,(~a weight))
      (cashOnDelivery . ,(pp-cents cod-amount))
      (insuredValue . ,(pp-cents insured-value))
      (awbPayment . "1") ;; client
      (awbRecipient . ,recipient)
      (parcels . ,parcel-dimensions)))
  (post c "/api/awb/estimate-cost" #:form (arraify fields)))

(define (get-awb-status awb [c (current-client)])
  (get c (~a "/api/client/awb/" awb "/status")))

(define (call-with-awb-pdf awb f
                           #:type [type 'A6]
                           #:client [c (current-client)])
  (define res
    (get c (~a "/api/awb/download/" awb "/" type) #:stream? #t))
  (dynamic-wind
    void
    (lambda ()
      (f (http:response-output res)))
    (lambda ()
      (http:response-close! res))))


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
  county
  city
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

(define (pp-cents v)
  (~r (/ v 100) #:precision '(= 2)))

(define (arraify params)
  (define (help k v)
    (cond
      [(not v) null]

      [(hash? v)
       (for/list ([(s-k s-v) (in-hash v)])
         (cons (string->symbol (format "~a[~a]" k s-k)) (~a s-v)))]

      [(list? v)
       (for/fold ([res null])
                 ([x (in-list v)]
                  [i (in-naturals)])
         (append (help (string->symbol (format "~a[~a]" k i)) x)))]

      [else
       (list (cons k (~a v)))]))

  (for/fold ([res null])
            ([p (in-list params)])
    (append (help (car p) (cdr p)) res)))
