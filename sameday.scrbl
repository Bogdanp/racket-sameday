#lang scribble/manual

@(require racket/runtime-path
          racket/sandbox
          scribble/example
          (for-label (except-in gregor date date?)
                     json
                     racket/base
                     racket/contract
                     sameday))

@title{Sameday}
@author[(author+email "Bogdan Popa" "bogdan@defn.io")]
@defmodule[sameday]

@(define sameday-link (link "https://sameday.ro" "Sameday"))

This package provides a Racket client for the @sameday-link API.

@section{Usage}

Instantiate and install a client:

@racketblock[
(require sameday)

(define c
 (make-client #:username "a-username"
              #:password "a-password"))

(current-client c)
]

Then start making API calls:

@racketblock[
(get-services)
]

Alternatively, all API calls can be provided an explicit client:

@racketblock[
(get-services c)
]


@section{Accessors}

@; Blatantly copied from sql-lib!
@(begin
   (define-syntax-rule (interaction e ...) (examples #:label #f e ...))
   (define-runtime-path log-file "sameday-log.rktd")
   (define log-mode (if (getenv "SAMEDAY_RECORD") 'record 'replay))
   (define (make-log-eval log-file)
     (define ev (make-log-based-eval log-file log-mode))
     (begin0 ev
       (ev '(require sameday (for-label sameday)))))
   (define log-eval (make-log-eval log-file)))

Most calls return @racket[jsexpr?] values and special, racket-y,
accessors are provided for each data type.  Every data type also
provides a smart constructor that takes in optional keyword arguments
for every field.

@interaction[
#:eval log-eval
(recipient #:type 'individual)

(code:line)
(define a-recipient
 (recipient
  #:city-id 1
  #:county-id 2
  #:address "111 Example St."
  #:name "John Doe"
  #:phone "1234567890"
  #:email "john.doe@example.com"
  #:type 'individual))
a-recipient

(code:line)
(recipient-name a-recipient)
]


@section{Reference}
@subsection{Client}

@defproc[(make-client [#:username username string?]
                      [#:password password string?]) client?]{
  Returns a new Sameday API client whose requests will be
  authenticated using the given @racket[username] and
  @racket[password].
}

@defproc[(client? [v any/c]) boolean?]{
  Returns @racket[#t] when @racket[v] is a Sameday API client.
}

@defparam[current-client client client? #:value #f]{
  A parameter that holds the current Sameday API client.
}

@defparam[current-client-root root string? #:value "https://api.sameday.ro"]{
  A parameter that holds the current API root.  All request URLs are
  relative to this address.
}

@subsection{AWB}

@defthing[cents/c (and/c exact-integer? (>=/c 100))]

@deftogether[(
  @defproc[(recipient? [v any/c]) boolean?]
  @defproc[(recipient [#:city-id city-id exact-positive-integer?]
                      [#:county-id county-id exact-positive-integer?]
                      [#:address address string?]
                      [#:postal-code postal-code string?]
                      [#:name name string?]
                      [#:phone phone string?]
                      [#:email email string?]
                      [#:type type (or/c 'individual 'company)]) recipient?]
  @defproc[(recipient-city-id [r recipient?]) exact-positive-integer?]
  @defproc[(recipient-county-id [r recipient?]) exact-positive-integer?]
  @defproc[(recipient-address [r recipient?]) string?]
  @defproc[(recipient-postal-code [r recipient?]) string?]
  @defproc[(recipient-name [r recipient?]) string?]
  @defproc[(recipient-phone [r recipient?]) string?]
  @defproc[(recipient-email [r recipient?]) string?]
  @defproc[(recipient-type [r recipient?]) (or/c 'individual 'company)]
)]

@deftogether[(
  @defproc[(awb? [v any/c]) boolean?]
  @defproc[(awb-number [a awb?]) exact-positive-integer?]
  @defproc[(awb-cost [a awb?]) cents/c]
  @defproc[(awb-parcels [a awb?]) (listof parcel?)]
)]

@deftogether[(
  @defproc[(awb-estimate? [v any/c]) boolean?]
  @defproc[(awb-estimate-amount [a awb-estimate?]) cents/c]
  @defproc[(awb-estimate-currency [a awb-estimate?]) string?]
)]

@deftogether[(
  @defproc[(awb-status? [v any/c]) boolean?]
  @defproc[(awb-status-parcels [a awb-status?]) (listof parcel?)]
)]

@deftogether[(
  @defproc[(parcel? [v any/c]) boolean?]
  @defproc[(parcel-status-id [p parcel?]) exact-positive-integer?]
  @defproc[(parcel-status [p parcel?]) string?]
  @defproc[(parcel-status-label [p parcel?]) string?]
  @defproc[(parcel-status-state [p parcel?]) string?]
  @defproc[(parcel-status-date [p parcel?]) moment?]
  @defproc[(parcel-county [p parcel?]) string?]
  @defproc[(parcel-reason [p parcel?]) string?]
  @defproc[(parcel-transit-location [p parcel?]) string?]
  @defproc[(parcel-awb [p parcel?]) string?]
  @defproc[(parcel-details [p parcel?]) string?]
  @defproc[(parcel-returning? [p parcel?]) boolean?]
)]

@deftogether[(
  @defproc[(parcel-dimensions? [v any/c]) boolean?]
  @defproc[(parcel-dimensions-weight [p parcel-dimensions?]) real?]
  @defproc[(parcel-dimensions-width [p parcel-dimensions?]) real?]
  @defproc[(parcel-dimensions-height [p parcel-dimensions?]) real?]
  @defproc[(parcel-dimensions-length [p parcel-dimensions?]) real?]
)]

@defproc[(create-awb! [recipient recipient?]
                      [#:service-id service-id exact-positive-integer?]
                      [#:pickup-point-id pickup-point-id exact-positive-integer?]
                      [#:contact-person-id contact-person-id exact-positive-integer?]
                      [#:package-type package-type 'parcel (or/c 'parcel 'envelope 'large)]
                      [#:parcel-dimensions parcel-dimensions null (listof parcel-dimensions?)]
                      [#:insured-value insured-value 0 cents/c]
                      [#:cod-amount cod-amount 0 cents/c]
                      [#:reference reference #f (or/c #f string?)]
                      [#:estimate? estimate? #f boolean?]
                      [#:client client (current-client) client?]) (or/c awb? awb-estimate?)]{

  Creates an AWB.

  When @racket[#:estimate?] is @racket[#t], an @racket[awb-estimate?]
  is returned instead and no AWB is created.

  The @racket[#:reference] keyword argument can be used to provide an
  internal reference.
}

@defproc[(delete-awb! [awb string?]
                      [c (current-client) client?]) void?]{

  Deletes the awb whose id is @racket[awb].
}

@defproc[(call-with-awb-pdf [awb string?]
                            [f (-> input-port? any)]
                            [#:type type 'A6 (or/c 'A4 'A6)]
                            [#:client client (current-client) client?]) any]{

  Calls @racket[f] with an input port containing the PDF data of the
  AWB whose id is @racket[awb].
}

@defproc[(get-awb-status [awb string?]
                         [c (current-client) client?]) awb-status?]{

  Gets the status and history of the AWB whose id is @racket[awb].
}

@subsection{Geolocation}

@deftogether[(
  @defproc[(county? [v any/c]) boolean?]
  @defproc[(county-id [c county?]) exact-positive-integer?]
  @defproc[(county-name [c county?]) string?]
  @defproc[(county-code [c county?]) string?]
)]

@deftogether[(
  @defproc[(city? [v any/c]) boolean?]
  @defproc[(city-id [c city?]) exact-positive-integer?]
  @defproc[(city-name [c city?]) string?]
  @defproc[(city-county [c city?]) county?]
  @defproc[(city-village [c city?]) string?]
  @defproc[(city-postal-code [c city?]) string?]
  @defproc[(city-logistic-circle [c city?]) string?]
  @defproc[(city-delivery-agency [c city?]) string?]
  @defproc[(city-pickup-agency [c city?]) string?]
  @defproc[(city-extra-km [c city?]) real?]
)]

@defproc[(get-counties [name #f (or/c #f string?)]
                       [#:page page 1 exact-positive-integer?]
                       [#:per-page per-page 100 exact-positive-integer?]
                       [#:client client (current-client) client?]) (page/c (listof county?))]{

  Returns a list of known counties, optionally filtered by name.
}

@defproc[(get-cities [name #f (or/c #f string?)]
                     [#:county-id county-id #f (or/c #f exact-positive-integer?)]
                     [#:postal-code postal-code #f (or/c #f string?)]
                     [#:page page 1 exact-positive-integer?]
                     [#:per-page per-page 100 exact-positive-integer?]
                     [#:client client (current-client) client?]) (page/c (listof city?))]{

  Returns a list of known cities, optionally filtered by name, county and postal code.
}

@subsection{Pickup Points}

@deftogether[(
  @defproc[(contact? [v any/c]) boolean?]
  @defproc[(contact-id [p contact?]) exact-positive-integer?]
  @defproc[(contact-name [p contact?]) string?]
  @defproc[(contact-phone-number [p contact?]) string?]
  @defproc[(contact-default? [p contact?]) boolean?]
)]

@deftogether[(
  @defproc[(pickup-point? [v any/c]) boolean?]
  @defproc[(pickup-point-id [p pickup-point?]) exact-positive-integer?]
  @defproc[(pickup-point-county-id [p pickup-point?]) exact-positive-integer?]
  @defproc[(pickup-point-city-id [p pickup-point?]) exact-positive-integer?]
  @defproc[(pickup-point-address [p pickup-point?]) string?]
  @defproc[(pickup-point-default? [p pickup-point?]) boolean?]
  @defproc[(pickup-point-contacts [p pickup-point?]) (listof contact?)]
  @defproc[(pickup-point-alias [p pickup-point?]) string?]
)]

@defproc[(get-pickup-points [c client? (current-client)]) (page/c (listof pickup-point?))]{
  Get the list of pickup points registered with your account.
}

@subsection{Services}

@deftogether[(
  @defproc[(delivery-type? [v any/c]) boolean?]
  @defproc[(delivery-type-id [t delivery-type?]) exact-integer?]
  @defproc[(delivery-type-name [t delivery-type?]) string?]
)]

@deftogether[(
  @defproc[(service? [v any/c]) boolean?]
  @defproc[(service-id [s service?]) exact-integer?]
  @defproc[(service-name [s service?]) string?]
  @defproc[(service-type [s service?]) delivery-type?]
  @defproc[(service-code [s service?]) string?]
  @defproc[(service-default? [s service?]) boolean?]
)]

@defproc[(get-services [c client? (current-client)]) (page/c (listof service?))]{
  Get the list of services provided by Sameday.
}

@subsection{Pagination}

@deftogether[(
  @defproc[(page? [v any/c]) boolean?]
  @defproc[(page-data [p page?]) list?]
  @defproc[(page-pages [p page?]) exact-positive-integer?]
  @defproc[(page-current [p page?]) exact-positive-integer?]
  @defproc[(page-per-page [p page?]) exact-positive-integer?]
  @defproc[(page-total [p page?]) exact-nonnegative-integer?]
)]

@defproc[(page/c [p (-> any/c boolean?)]) (-> any/c boolean?)]{
  A higher-order contract that applies @racket[p] to a page's data.
}
