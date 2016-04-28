(defmodule knot
  ; Export all for testing.
  (export all))

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
(defun replace-code-a-lot [delimiters code-map]
  "Replace code five times to handle nested references."
  (: lists foldl
    (lambda [_ code-map]
      (replace-code delimiters code-map))
    code-map
    (: lists seq 1 5)))
(defun code-output [code-map]
  (maps:fold (match-lambda
              ([(binary #\f #\i #\l #\e #\: (file-name binary)) contents acc]
                (maps:put file-name contents acc))
              ([_ _ acc]
                acc))
             (map)
             code-map))
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
(defun read-delimiters
  ([#""]
    '())
  ([(binary #x000a (_rest binary))]
    '())
  ([(binary #\< #\! #\- #\- #\  #\K #\n #\o #\t #\  #\d #\e #\l #\i #\m #\i #\t #\e #\r #\s (rest binary))]
    (read-quoted-strings rest))
  ([(binary (char utf8) (rest binary))]
    (read-delimiters rest)))
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