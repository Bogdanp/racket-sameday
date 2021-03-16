#lang racket/base

(require (for-syntax racket/base
                     racket/list
                     racket/syntax)
         syntax/parse/define)

(provide
 json-view)

(begin-for-syntax
  (define (name->field-id name)
    (string->symbol
     (regexp-replace* #rx"\\?|-[a-z]"
                      (symbol->string name)
                      (λ (m)
                        (case (string-ref m 0)
                          [(#\?) ""]
                          [(#\-) (string-upcase (substring m 1))])))))

  (define-syntax-class field
    #:attributes (name field-id reader writer)
    (pattern name:id
             #:with field-id (name->field-id (syntax-e #'name))
             #:with reader #'values
             #:with writer #'values)
    (pattern [(~or name:id (name:id fld-id:id))
              (~alt
               (~optional (~seq #:reader reader-e:expr))
               (~optional (~seq #:writer writer-e:expr))) ...]
             #:with field-id #`(~? fld-id #,(name->field-id (syntax-e #'name)))
             #:with reader #'(~? reader-e values)
             #:with writer #'(~? writer-e values))))

(define-syntax-parser json-view
  [(_ name:id (fld:field ...))
   #:with name? (format-id #'name "~a?" #'name)
   #:with (mk-kwarg ...) (flatten
                          (for/list ([fld-name (in-list (syntax-e #'(fld.name ...)))])
                            (define kwd (string->keyword (symbol->string (syntax-e fld-name))))
                            (list kwd #`(#,fld-name #f))))
   #:with (mk-arg ...) (flatten
                        (for/list ([fld-name (in-list (syntax-e #'(fld.name ...)))]
                                   [fld-id (in-list (syntax-e #'(fld.field-id ...)))]
                                   [fld-writer (in-list (syntax-e #'(fld.writer ...)))])
                          (list #`(quote #,fld-id) #`(#,fld-writer #,fld-name))))
   #:with (fld-name ...) (for/list ([fld-name (in-list (syntax-e #'(fld.name ...)))])
                           (format-id #'name "~a-~a" #'name fld-name))
   #'(begin
       (provide name? name fld-name ...)
       (define (name? h)
         (and (hash-eq? h)
              (hash-has-key? h 'fld.field-id) ...))
       (define (name mk-kwarg ...)
         (hasheq mk-arg ...))
       (define (fld-name h)
         (fld.reader (hash-ref h 'fld.field-id))) ...)])
