<!-- Knot delimiters: "«" "»" -->
# Knot

Knot is a literate programming tool that uses Markdown. Knot is unique in that
it doesn't generate any documentation -- only source code.



**TODO**: Consider reorganizing the program along the lines of the types
produced, i.e. code map, replaced code, and output files. I'm also annoyed at
my function names. 😒



# Development Environment

I wrote a version of Knot in Erlang already. I wanted to use LFE at the time
but it was a dependency that I didn't want to add. Now that I know about
Docker, I can do whatever I want.

I can use the existing version of Knot to generate the source code for the new
version. I'm going to use Docker Compose to output source code from this file.
When I start working, I only need to `docker-compose up -d`.

###### file:docker-compose.yml
    # Don't change this file. It was generated from knot.md.
    knot:
      image: mqsoh/knot
      volumes:
        - .:/workdir
      command: .

[I bundled another Docker image for LFE with some nice features
(mqsoh/lfe-watcher).][] This image will

- start a shell,
- watch `src/` and compile to `ebin/`, and
- watch `ebin/` and reload modules in the shell.

The image assumes that you'll always have the shell running as you're
developing. I'll wrap the Docker command to start it in a script.

###### file:shell
    #!/bin/bash
    # Don't change this file. It was generated from knot.md.
    docker run --interactive --tty --rm --volume $(pwd):/workdir mqsoh/lfe-watcher

# The Program

Here's the module.

###### file:src/knot.lfe
    (defmodule knot
      ; Export all for testing.
      (export all))

    «Extract code.»
    «Replace code.»
    «Configurable delimiters.»
    «Input and output.»

### Extract Code from the Source File

I'll support indented and fenced Markdown code blocks. Fenced code blocks both
start and end with a line that starts with three backticks. For example:

    I am not code.

    ```
    function hello() {
        console.log("Now I'm writing code.");
    }
    ```

    Also not code.

Indented code blocks are lines that start with four spaces. For example:

    I am not code.

        function hello() {
            console.log("Now I'm writing code.");
        }

    Also not code.

Code blocks need names because they'll be referenced in other code blocks. In
Knot files, an H6 will name a code block and only the leading-hash style is
supported.

    # My Section

    The code I'm about to write is a function that prints a message to the
    console in JavaScript.

    ###### My Code

        function hello() {
            console.log("Now I'm writing code.");
        }

The code section will be named `My Code`.

###### Extract code.

`extract-code` will take the contents of a file and return a map of named code
sections. A file will start with documentation. A code block will be given the
name of the preceding H6 heading.

###### Extract code.
    (defun extract-code [bitstring]
      (extract-code (binary (#"\n" binary) (bitstring binary))
                    'nil
                    (map)))

    (defun extract-code
      ([#"" _ code-map]
        code-map)

      ; H6 Heading.
      ([(binary #x000a #\# #\# #\# #\# #\# #\# (heading-start binary)) name code-map]
        (let* ([(list new-name rest) (: binary split heading-start #"\n")]
               [trimmed-name (: re replace new-name #"^#* *" "" '(#(return binary)))])
          (extract-code (binary #x000a (rest binary)) trimmed-name code-map)))

      ; Fenced code.
      ([(binary #x000a #\` #\` #\` (rest binary)) name code-map] (when (/= name 'nil))
        (let* ([(list _ code-start) (: binary split rest #"\n")]
               [(list code next-documentation) (: binary split code-start #"\n```")]
               [merged-code (case (: maps get name code-map #"")
                                  (#"" code)
                                  (existing-code
                                    (binary (existing-code binary) #x000a (code binary))))])
          (extract-code next-documentation 'nil (: maps put name merged-code code-map))))

      ; Indented code.
      ([(binary #x000a #\  #\  #\  #\  (rest binary)) name code-map] (when (/= name 'nil))
        (let* ([(list code next-documentation) (indented-split rest)]
               [merged-code (case (: maps get name code-map #"")
                                  (#"" code)
                                  (existing-code
                                    (binary (existing-code binary) #x000a (code binary))))])
          (extract-code next-documentation 'nil (: maps put name merged-code code-map))))

      ([(binary (char utf8) (rest binary)) name code-map]
        (extract-code rest name code-map)))

    «Collect indented code.»

A file might have a heading on the first line. To ensure that the `H6 Heading`
block matches I prepend a line break to the entire input in `extract-code/1`.

In the `H6 Heading` block, I prepend a line break to the recursive call. I
added it so that code blocks could be matched on the line directly following
the heading. Otherwise, an empty line between the header and code block would
be required.

Fenced code is easy to handle since I can just use `binary:split` to gather all
the code between the fences.

Indented code is more difficult and I've delegated to an unimplemented funtion
called `indented-split` to handle it.

###### Collect indented code.
    (defun indented-split [bitstring]
      (indented-split bitstring '()))

    (defun indented-split
      ([#"" acc]
        (list (indented-split-termination acc)
              #""))

      ([(binary #x000a (char utf8) (rest binary)) acc] (when (> char 32))
        (list (indented-split-termination acc)
              (: unicode characters_to_binary (cons #x000a (cons char rest)))))

      ([(binary #x000a #\  #\  #\  #\  (rest binary)) acc]
        (indented-split rest (cons #x000a acc)))

      ([(binary (char utf8) (rest binary)) acc]
        (indented-split rest (cons char acc))))

    (defun indented-split-termination [acc]
      (: re replace (: unicode characters_to_binary (: lists reverse acc))
                    #"[\s\n]+$"
                    ""
                    '(#(return binary))))

The first block is a terminating condition when the input is exhausted. The
second is also a terminating condition for when a line starts with non-white
space -- the end of the code block.

The third block strips the leading four spaces of a line.

Finally, for any other condition, I collect a character in the accumultor and
recurse.

The `indented-split-termination` function is used to strip trailing white space
in the `indented-split` terminating conditions. This is necessary because I
can't identify the end of an indented section until the start of a new
documentation section, so there will always be extraneous line breaks at the
end of the indented blocks. However, they shouldn't be a part of the output.
For example, in the following section, there should be no line breaks after
`code`.

    Documentation.

        code

    More documentation.



### Replacing Code Sections

I'll write the functions to replace code from the inside out. I need functions
to:

###### Replace code.
    «take a line and replace it with the referenced code block»
    «do it for every line in a code block»
    «do it for every code block in a code map»
    «do it enough times to handle nested sections»
    «throw out everything except the files»

The code map will have code blocks; inside the code blocks, there may be a line
that has a reference to another code section. If it doesn't, I'll just return
the input. Otherwise, replace the reference with the code section.

There's a unique feature here. I'll maintain the line's prefix and suffix. For
example, given a reference like this: `<li><<reference>></li>` and a code
section like this:

    one
    two
    three

Knot will output code like this:

    <li>one</li>
    <li>two</li>
    <li>three</li>

###### take a line and replace it with the referenced code block
    (defun replace-line [line delimiters code-map]
      "For a single code line, replace with the contents of a code map. (If no
      `delimiters` are found, the input line is returned."
      (case (: binary split line delimiters '(global))
            ; A replacement is found.
            ((list prefix key suffix)
              (case (maps:get key code-map #"")
                    (#""
                      (io:format "Knot warning: Code block \"~s\" not found.~n" `(,key))
                      line)
                    (replacement-block
                      (let* ([replacement-lines (: binary split replacement-block #"\n" '(global))]
                             [(cons first rest) replacement-lines])
                        ; Apply prefix and suffix to all lines in referenced block.
                        (: lists foldl
                          (lambda [line acc]
                            (binary (acc binary)
                                    (#"\n" binary)
                                    (prefix binary)
                                    (line binary)
                                    (suffix binary)))
                          (binary (prefix binary) (first binary) (suffix binary))
                          rest)))))
            ; Return the input line.
            (_
              line)))

The `replace-line` function first uses the case statement to split the line up
into a line prefix, the name of the code map to insert, and the line suffix. If
there is no referenced section, then it just returns the input line: `(_ line)`.

If there's a reference to a nonexistent block, a warning is printed to the
console.

When a replacement is found the referenced block is split up into lines and the
prefix and suffix are applied to each line.

###### do it for every line in a code block

I need to check all the lines in a code block for replacement sections. The
`lists:foldl` does a `replace-line` on every line in the code block.

    (defun replace-lines [lines delimiters code-map]
      "For a block of code, apply `replace-line` for every line."
      (let ([(cons first rest) (: binary split lines #"\n" '(global))])
        (: lists foldl
          (lambda [line acc]
            (binary (acc binary)
                    (#"\n" binary)
                    ((replace-line line delimiters code-map) binary)))
          (replace-line first delimiters code-map)
          rest)))

###### do it for every code block in a code map

For every item in a code map, apply `replace-lines` to each value.

    (defun replace-code [delimiters code-map]
      "For every block of code, apply `replace-lines`."
      (replace-code (: maps keys code-map) delimiters code-map))

    (defun replace-code
      (['() _ code-map]
        code-map)

      ([(cons key keys) delimiters code-map]
        (let* ([code (: maps get key code-map)]
               [new-code (replace-lines code delimiters code-map)])
          (replace-code keys delimiters (: maps put key new-code code-map)))))

###### do it enough times to handle nested sections

Code blocks can reference other code blocks. The following function iterates
over the code map five times. This is one thing that could be improved. I could
detect detect recursive blocks or at least check how many iterations are
needed.

    (defun replace-code-a-lot [delimiters code-map]
      "Replace code five times to handle nested references."
      (: lists foldl
        (lambda [_ code-map]
          (replace-code delimiters code-map))
        code-map
        (: lists seq 1 5)))

Now I need to reduce the code map to a map that contains only the items with
keys that start with `file:`. I'll also strip the `file:` prefix. For example,
given a bitstring that contains a Markdown document, I want to return a map of
files and contents.

    (map #"src/knot.lfe"
          #"(defmodule knot (export all)) ..."
         #"src/knot_tests.lfe"
          #"(defmodule knot_tests (export all)) ...")

###### throw out everything except the files
    (defun code-output [code-map]
      (maps:fold (match-lambda
                  ([(binary #\f #\i #\l #\e #\: (file-name binary)) contents acc]
                    (maps:put file-name contents acc))
                  ([_ _ acc]
                    acc))
                 (map)
                 code-map))



### Configurable Delimiters.

I'm almost ready to tie it all together. I've written all the functions up to
now to accept delimiters for the replacement sections. Now I want to make it
configurable for the user.

Since my literate programs often mix languages, I actually think it would be
best to enable the delimiters to be defined and redefined at any point in the
document. To do that, I need to stop using the code map and instead make it a
list that contains both code blocks and delimiter definitions.

In the mean time I'm just going to support one delimiter definition. It should
be an HTML comment with a list of delimiters. Each delimiter is surrounded by
quotes and a literal quote in the delimiter can be escaped with a backslash.
*This directive must be on the first line of the document.*

    <!-- Knot delimiters: "foo" "\"bar\"" -->

###### Configurable delimiters.
    (defun read-quoted-string [bitstring]
      (read-quoted-string bitstring '()))

    (defun read-quoted-string
      ([#"" acc]
        (tuple (unicode:characters_to_binary (lists:reverse acc)) #""))
      ([(binary #\" (rest binary)) acc]
        (tuple (unicode:characters_to_binary (lists:reverse acc)) rest))
      ([(binary #\\ #\" (rest binary)) acc]
        (read-quoted-string rest (cons #\" acc)))
      ([(binary (char utf8) (rest binary)) acc]
        (read-quoted-string rest (cons char acc))))

A quoted string ends in a closing quote. The opening quote is detected and
consumed by `read-quoted-strings`.

###### Configurable delimiters.
    (defun read-quoted-strings [bitstring]
      (read-quoted-strings bitstring '()))

    (defun read-quoted-strings
      ([#"" acc]
        (lists:reverse acc))
      ([(binary #\- #\- #\> (rest binary)) acc]
        (lists:reverse acc))
      ([(binary #\" (rest binary)) acc]
        (let ([(tuple quoted-string rest2) (read-quoted-string rest)])
          (read-quoted-strings rest2 (cons quoted-string acc))))
      ([(binary (char utf8) (rest binary)) acc]
        (read-quoted-strings rest acc)))

A list of quoted strings ends with the closing of an HTML comment. The opening
is detected and consumed by `read-delimiters`.

###### Configurable delimiters.
    (defun read-delimiters
      ([#""]
        '())
      ([(binary #x000a (_rest binary))]
        '())
      ([(binary #\< #\! #\- #\- #\  #\K #\n #\o #\t #\  #\d #\e #\l #\i #\m #\i #\t #\e #\r #\s (rest binary))]
        (read-quoted-strings rest))
      ([(binary (char utf8) (rest binary))]
        (read-delimiters rest)))



### Input and Output

Now I can tie it all together. The `process` function takes the contents of a
Markdown file as a bitstring and returns a file map, which is a map with keys
as file names and values as the contents of the file. The `process-file` wraps
`process` by reading from a file and writing the files referred to in the file
map. The basedir of that file is used as the basedir of the output
files.

The `process-file` steps are:

- Check for configurable delimiters.
- Convert the document into a code map.
- Run replacements for all code blocks.
- Reduce the code map to a file map.
- Write files.

###### Input and output.
    (defun process [markdown]
      (let* ([delimiters (case (read-delimiters markdown)
                               ('() '(#"<<" #">>"))
                               (delimiters delimiters))]
             [code-map (extract-code markdown)]
             [replaced-code-map (replace-code-a-lot delimiters code-map)])
        (code-output replaced-code-map)))

    (defun process-file [file-name]
      (let* ([basedir (filename:dirname file-name)]
             [(tuple 'ok markdown) (file:read_file file-name)]
             [file-map (process markdown)])
        (maps:fold (lambda [output-file-name contents acc]
                    (let* ([fn (binary (basedir binary) #\/ (output-file-name binary))]
                           [_ (io:format "Knot writing file: ~s~n" `(,fn))]
                           ['ok (file:write_file fn contents)])
                      (cons fn acc)))
                   '()
                   file-map)))



[I bundled another Docker image for LFE with some nice features (mqsoh/lfe-watcher).]: https://github.com/mqsoh/lfe-watcher
