#lang info

(define version "1.0")
(define collection "sameday")
(define deps '("base"
               "gregor-lib"
               "http-easy"))
(define build-deps '("gregor-doc"
                     "racket-doc"
                     "rackunit-lib"
                     "sandbox-lib"
                     "scribble-lib"))
(define scribblings '(("sameday.scrbl")))
