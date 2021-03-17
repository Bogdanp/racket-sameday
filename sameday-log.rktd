;; This file was created by make-log-based-eval
((require sameday (for-label sameday))
 ((3) 0 () 0 () () (c values c (void)))
 #""
 #"")
((recipient #:type 'individual)
 ((3)
  0
  ()
  0
  ()
  ()
  (c
   values
   c
   (h
    -
    ()
    (phoneNumber . #f)
    (email . #f)
    (county . #f)
    (name . #f)
    (city . #f)
    (address . #f)
    (personType . 0)
    (postalCode . #f))))
 #""
 #"")
((define a-recipient
   (recipient
    #:city-id
    1
    #:county-id
    2
    #:address
    "111 Example St."
    #:name
    "John Doe"
    #:phone
    "1234567890"
    #:email
    "john.doe@example.com"
    #:type
    'individual))
 ((3) 0 () 0 () () (c values c (void)))
 #""
 #"")
(a-recipient
 ((3)
  0
  ()
  0
  ()
  ()
  (c
   values
   c
   (h
    -
    ()
    (phoneNumber . "1234567890")
    (email . "john.doe@example.com")
    (county . 2)
    (name . "John Doe")
    (city . 1)
    (address . "111 Example St.")
    (personType . 0)
    (postalCode . #f))))
 #""
 #"")
((recipient-name a-recipient) ((3) 0 () 0 () () (q values "John Doe")) #"" #"")
