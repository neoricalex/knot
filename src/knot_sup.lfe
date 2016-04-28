(defmodule knot_sup
  (export all))

(defun start_link []
  (supervisor:start_link #(local knot_sup) 'knot_sup '()))

(defun init
  (['()]
    #(ok #(#m(strategy one_for_one
              intensity 10
              period 1)
           (#m(id knot_server_laskdjf
               start #(knot_server start_link ())
               ))))))