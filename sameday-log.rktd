;; This file was created by make-log-based-eval
((require sameday (for-label sameday))
 ((3) 0 () 0 () () (c values c (void)))
 #""
 #"")
((recipient)
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
    (email . #f)
    (county . #f)
    (name . #f)
    (city . #f)
    (address . #f)
    (phone . #f))))
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
    "john.doe@example.com"))
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
    (email . "john.doe@example.com")
    (county . 2)
    (name . "John Doe")
    (city . 1)
    (address . "111 Example St.")
    (phone . "1234567890"))))
 #""
 #"")
((recipient-name a-recipient) ((3) 0 () 0 () () (q values "John Doe")) #"" #"")
