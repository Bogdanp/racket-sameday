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
  [delete-awb (->* (string?) (client?) void?)]
  [get-awb-status (->* (string?) (client?) awb-status?)]
  [get-pickup-points (->* () (client?) (page/c (listof pickup-point?)))]
  [get-services (->* () (client?) (page/c (listof service?)))]))


;; common data types ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(provide page/c)

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
  parcel-awb-number))

(define (delete-awb awb [c (current-client)])
  (void (delete c (~a "/api/awb/" awb))))

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

(json-view
 delivery-type
 (id
  name))

(json-view
 service
 (id
  name
  [(type deliveryType)]
  [(code serviceCode)]
  [(default? defaultServices)]))

(define (get-services [c (current-client)])
  (get c "/api/client/services"))
