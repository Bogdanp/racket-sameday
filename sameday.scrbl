#lang scribble/manual

@(require (for-label json
                     racket/base
                     racket/contract
                     sameday))

@title{Sameday}
@author[(author+email "Bogdan Popa" "bogdan@defn.io")]
@defmodule[sameday]

@(define sameday-link (link "https://sameday.ro" "Sameday"))

This package provides a Racket client for the @sameday-link API.  This
is currently a WIP and most endpoints are not yet implemented.

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

Most calls return @racket[jsexpr?] values and special, racket-y,
accessors are provided for each data type.


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

@subsection{Services}

@deftogether[(
  @defproc[(delivery-type? [v any/c]) boolean?]
  @defproc[(delivery-type-id [s service?]) exact-integer?]
  @defproc[(delivery-type-name [s service?]) string?]
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
