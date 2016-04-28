(defmodule knot_tests
  (export all))

(include-lib "eunit/include/eunit.hrl")

(defun |extract-code  _test| []
  (let* ([text '(
            "# Test Documentation"
            ""
            "I'll start with some documentation before the first test of fenced code. The"
            "fences need to be prefixed with some character so that they don't terminate"
            "this containing block (`>`). Once Knot is upgraded I can switch this to an"
            "indented block."
            ""
            "###### Fenced Code"
            ""
            "```"
            "Fenced code 1."
            ""
            "Fenced code 2."
            "```"
            ""
            "### Another Heading"
            ""
            "I'm putting another heading here to ensure that it doesn't mess up the search"
            "for the following H6 heading."
            ""
            "Now I'll test indented code."
            ""
            "###### Indented Code"
            ""
            "    Indented code 1."
            ""
            "    Indented code 2."
            ""
            "GitHub's Markdown parser used to require blank lines surrounding code blocks"
            "but no longer does. I want Knot to support this style as well, so here are the"
            "fenced and indented blocks again."
            ""
            "###### Fenced Code 2"
            "```"
            "Fenced code 2-1."
            ""
            "Fenced code 2-2."
            "```"
            "...and indented..."
            ""
            "###### Indented Code 2"
            "    Indented code 2-1."
            ""
            "    Indented code 2-2."
            "This is the end of the test document."
          )]
         [input (erlang:list_to_binary (string:join text "\n"))]
         [output (knot:extract-code input)]
         ['true (== output #m(#"Fenced Code" #"Fenced code 1.\n\nFenced code 2."
                              #"Indented Code" #"Indented code 1.\n\nIndented code 2."
                              #"Fenced Code 2" #"Fenced code 2-1.\n\nFenced code 2-2."
                              #"Indented Code 2" #"Indented code 2-1.\n\nIndented code 2-2."))])))
(defun |replace-line with nonexistent code block _test| []
  (let* ([line #"- ..replace me.. -"]
         [delimiters '(#"..")]
         [code-map (map #"not" #"used")]
         [#"- ..replace me.. -" (knot:replace-line line delimiters code-map)])))

(defun |replace-line with a single line _test| []
  (let* ([line #"- ..replace me.. -"]
         [delimiters '(#"..")]
         [code-map (map #"replace me" #"replaced")]
         [#"- replaced -" (knot:replace-line line delimiters code-map)])))

(defun |replace-line with multiple lines _test| []
  (let* ([line #"- ..replace me.. -"]
         [delimiters '(#"..")]
         [code-map (map #"replace me" #"foo\nbar\nbaz")]
         [#"- foo -\n- bar -\n- baz -" (knot:replace-line line delimiters code-map)])))

(defun |replace-line with multiple delimiters _test| []
  (let* ([line #"- (-- replace me --) -"]
         [delimiters '(#"(-- " #" --)")]
         [code-map (map #"replace me" #"replaced")]
         [#"- replaced -" (knot:replace-line line delimiters code-map)]
         [#"- replaced -" (knot:replace-line #"-  --)replace me(--  -" delimiters code-map)])))
(defun |replace-lines with nonexistent code block _test| []
  (let* ([lines #"- ..replace me.. -\n- ..replace me.. -"]
         [delimiters '(#"..")]
         [code-map (map #"not" #"used")]
         [#"- ..replace me.. -\n- ..replace me.. -" (knot:replace-lines lines delimiters code-map)])))

(defun |replace-lines with a multiline code block with multiple references _test| []
  (let* ([lines #"- ..replace me.. -\n- ..replace me too.. -"]
         [delimiters '(#"..")]
         [code-map (map #"replace me" #"replaced 1\nreplaced 2"
                        #"replace me too" #"also replaced 1\nalso replaced 2")]
         [#"- replaced 1 -\n- replaced 2 -\n- also replaced 1 -\n- also replaced 2 -" (knot:replace-lines lines delimiters code-map)])))
(defun |replace-code for a code map with one item _test| []
  (let* ([delimiters '(#"..")]
         [code-map (map #"html" #"<ul>\n<li>..mylist..</li>\n</ul>"
                        #"mylist" #"one\ntwo\nthree")]
         [output (map #"html" #"<ul>\n<li>one</li>\n<li>two</li>\n<li>three</li>\n</ul>"
                      #"mylist" #"one\ntwo\nthree")]
         ['true (== output (knot:replace-code delimiters code-map))])))
(defun |code-output with no files given _test| []
  (let* ([input (map #"foo" #"bar" #"baz" #"buzz")]
         [output (knot:code-output input)]
         ['true (== output (map))])))

(defun |code-output with one file _test| []
  (let* ([input (map #"file:src/knot.lfe" #"(defmodule ...) ..." #"foo" #"bar")]
         [output (knot:code-output input)]
         ['true (== output (map #"src/knot.lfe" #"(defmodule ...) ..."))])))
(defun |read-quoted-string _test| []
  (let* ([input #"quoted string with a \\\"quote\\\" here\"..."]
         [(tuple output #"...") (knot:read-quoted-string input)]
         [#"quoted string with a \"quote\" here" output])))

(defun |read-quoted-string with unicode _test| []
  (let* ([input #"\\\"🚀\\\"\"..."] ; a rocket in quotes
         [(tuple output #"...") (knot:read-quoted-string input)]
         [#"\"🚀\"" output])))

(defun |read-quoted-strings _test| []
  (let* ([input #"...\"foo\" \"bar\" -->"]
         ['(#"foo" #"bar") (knot:read-quoted-strings input)])))

(defun |read-delimiters _test| []
  (let* ([input #"...<!-- Knot delimiters: \"foo\" \"bar\" -->..."]
         ['(#"foo" #"bar") (knot:read-delimiters input)])))

(defun |read-delimiters none defined _test| []
  (let* ([input #"......"]
         ['() (knot:read-delimiters input)])))
(defun |process _test| []
  (let* ([test-doc-contents (erlang:iolist_to_binary '(
                              "<!-- Knot delimiters: \"😆\" -->\n"
                              "# I/O test document.\n"
                              "\n"
                              "First I want to create an HTML file with a list of things.\n"
                              "\n"
                              "###### things\n"
                              "    thing 1\n"
                              "    thing 2\n"
                              "    thing 3\n"
                              "\n"
                              "###### file:htdocs/index.html\n"
                              "    <!doctype html>\n"
                              "    This is a list.\n"
                              "    <ul>\n"
                              "      <li>😆things😆</li>\n"
                              "    </ul>\n"
                              "\n"
                              "Now I want to output a JavaScript file. I'll use the same list of things, but\n"
                              "this time I'll log them to the console.\n"
                              "\n"
                              "###### file:js/index.js\n"
                              "    (function () {\n"
                              "      alert(\"😆things😆\");\n"
                              "    }());\n"
                            ))]
         [output (knot:process test-doc-contents)]
         [expected (map #"htdocs/index.html" #"<!doctype html>\nThis is a list.\n<ul>\n  <li>thing 1</li>\n  <li>thing 2</li>\n  <li>thing 3</li>\n</ul>"
                        #"js/index.js" #"(function () {\n  alert(\"thing 1\");\n  alert(\"thing 2\");\n  alert(\"thing 3\");\n}());")]
         ['true (== expected output)])))

(defun |process-file _test| []
  (let* ([test-doc-contents '(
                              "<!-- Knot delimiters: \"😆\" -->\n"
                              "# I/O test document.\n"
                              "\n"
                              "First I want to create an HTML file with a list of things.\n"
                              "\n"
                              "###### things\n"
                              "    thing 1\n"
                              "    thing 2\n"
                              "    thing 3\n"
                              "\n"
                              "###### file:htdocs/index.html\n"
                              "    <!doctype html>\n"
                              "    This is a list.\n"
                              "    <ul>\n"
                              "      <li>😆things😆</li>\n"
                              "    </ul>\n"
                              "\n"
                              "Now I want to output a JavaScript file. I'll use the same list of things, but\n"
                              "this time I'll log them to the console.\n"
                              "\n"
                              "###### file:js/index.js\n"
                              "    (function () {\n"
                              "      alert(\"😆things😆\");\n"
                              "    }());\n"
                            )]

         [tempdir (binary:list_to_bin (lib:nonl (os:cmd "mktemp --directory")))]
         [test-doc-fn (binary (tempdir binary) (#"/doc.md" binary))]
         [html-fn (binary (tempdir binary) (#"/htdocs/index.html" binary))]
         [js-fn (binary (tempdir binary) (#"/js/index.js" binary))]

         ['ok (filelib:ensure_dir test-doc-fn)]
         ['ok (filelib:ensure_dir html-fn)]
         ['ok (filelib:ensure_dir js-fn)]

         [_ (io:format "process _test writing files~n")]

         ['ok (file:write_file test-doc-fn test-doc-contents)]
         [output-files (knot:process-file test-doc-fn)]
         [_ (io:format "output-files: ~p~n" `(,output-files))]
         ['true (lists:member html-fn output-files)]
         ['true (lists:member js-fn output-files)]

         [_ (io:format "process _test checking contents~n")]

         [(tuple 'ok #"<!doctype html>\nThis is a list.\n<ul>\n  <li>thing 1</li>\n  <li>thing 2</li>\n  <li>thing 3</li>\n</ul>") (file:read_file html-fn)]
         [(tuple 'ok #"(function () {\n  alert(\"thing 1\");\n  alert(\"thing 2\");\n  alert(\"thing 3\");\n}());") (file:read_file js-fn)])

    (io:format "process _test cleaning up: ~p~n"
               (list (os:cmd (binary:bin_to_list (binary (#"rm -rf " binary) (tempdir binary))))))))