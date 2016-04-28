<!-- Knot delimiters: "«" "»" -->
# Knot Application

*Not used!* Initially I thought I would need an OTP application to efficiently
process files in the Docker image. That wasn't the case. Usually I would delete
this program however, I have an idea for a project that will probably need
this.

I'm going to wrap [the Knot code][] inside an OTP application. In the past,
errors in a Markdown source document have crashed the process watching the
filesystem for changes. That's terrible, so I'm going to use an Erlang
supervision tree.

Supervision trees are easy to understand conceptually, but I had a lot of
trouble actually using one. I wrote [a demo application to monitor web pages][]
to attempt to understand it more. If anything here seems confusing, that
program might help.

The tree I'll be implementing couldn't be simpler:

    Application (callback module is `knot_app`)
      v
    Supervisor (callback module is `knot_sup`)
      v
    Worker (module is `knot_server`)

All Erlang applications need a `.app` file. This file specifies which module is
the application callback module. I want it to be `knot_app`.

###### file:ebin/knot.app
    {application, knot, [
      {mod, {knot_app, []}}
    ]}.

The application callback module doesn't do anything except tell the supervisor
module to start a supervisor linked to the application. (This is a bit of
standard weirdness in Erlang code that I mentioned in [my demo application][].)

###### file:src/knot_app.lfe
    (defmodule knot_app
      (export all))

    (defun start [_type _args]
      (knot_sup:start_link))

    (defun stop [_state]
      'ok)

Now the supervisor module has the function called in `knot_app` to start itself
and an `init` function to specify child workers and their restart strategy.

###### file:src/knot_sup.lfe
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

Initially I thought that a `simple_one_for_one` restart strategy was
applicable. I then used `supervisor:start_child` to manually start the child.
However, I couldn't figure out how to get the supervisor to restart the
process. It turns out that a `one_for_one` strategy is what I wanted. With
one_for_one the listed child specs are automatically started and restarted when
they crash -- which is what I was expecting.

The `start` function is specified as `knot_server:start_link` and passes no
arguments. Here's that function.

###### start link
    (defun start_link []
      (gen_server:start_link #(local knot_server) 'knot_server '() '()))

Now I need to build the worker which will be a `gen_server`. The gen_server
behavior requires some functions that we don't need to implement.

###### unused gen_server functions
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

The only gen_server function I need to implement is the one that receives
messages. I need to handle two different messages: one for `knot:process` and
another for `knot:process-file`.

###### useful gen_server function
    (defun handle_call
      ([(tuple 'process markdown) _from state]
        (tuple 'reply (knot:process markdown) state))
      ([(tuple 'process-file file-name) _from state]
        (tuple 'reply (knot:process-file file-name) state))
      ([_message _from state]
        (tuple 'noreply state)))

And now I'll create functions that wrap the `gen_server:call`s so that the user
only needs to do:

    application:start(knot).
    knot_server:process("markdown contents").
    knot_server:process_file("/path/to/doc.md").

###### api
    (defun process [markdown]
      (gen_server:call 'knot_server (tuple 'process markdown)))

    (defun process-file [file-name]
      (gen_server:call 'knot_server (tuple 'process-file file-name)))

Put all that in the file!

###### file:src/knot_server.lfe
    (defmodule knot_server
      (export all))

    «start link»
    «unused gen_server functions»
    «useful gen_server function»
    «api»



[the Knot code]: ./knot.md
[a demo application to monitor web pages]: https://github.com/mqsoh/mon
[my demo application]: https://github.com/mqsoh/mon
