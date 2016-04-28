(defmodule knot_server
  (export all))

(defun start_link []
  (gen_server:start_link #(local knot_server) 'knot_server '() '()))
(defun init [args]
  (tuple 'ok '()))

(defun handle_cast [_request state]
  (tuple 'noreply state))

(defun handle_info [_info state]
  (tuple 'noreply state))

(defun terminate [_reason _state]
  'return_value_ignored)

(defun code_change [_old-version state _extra]
  (tuple 'ok state))
(defun handle_call
  ([(tuple 'process markdown) _from state]
    (tuple 'reply (knot:process markdown) state))
  ([(tuple 'process-file file-name) _from state]
    (tuple 'reply (knot:process-file file-name) state))
  ([_message _from state]
    (tuple 'noreply state)))
(defun process [markdown]
  (gen_server:call 'knot_server (tuple 'process markdown)))

(defun process-file [file-name]
  (gen_server:call 'knot_server (tuple 'process-file file-name)))