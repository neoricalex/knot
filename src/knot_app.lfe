(defmodule knot_app
  (export all))

(defun start [_type _args]
  (knot_sup:start_link))

(defun stop [_state]
  'ok)