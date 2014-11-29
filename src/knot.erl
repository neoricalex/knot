-module(knot).
-compile(export_all).

collect_to_eol(Input) ->
    collect_to_eol(Input, "").

collect_to_eol("", Acc) ->
    {lists:reverse(Acc), ""};

collect_to_eol([$\n | Rest], Acc) ->
    {lists:reverse(Acc), Rest};

collect_to_eol([Char | Rest], Acc) ->
    collect_to_eol(Rest, [Char | Acc]).
collect_to_fence(Input) ->
    collect_to_fence(Input, "").

collect_to_fence("", Acc) ->
    {lists:reverse(Acc), ""};

collect_to_fence([$\n, $`, $`, $` | Rest], Acc) ->
    {lists:reverse(Acc), Rest};

collect_to_fence([Char | Rest], Acc) ->
    collect_to_fence(Rest, [Char | Acc]).
collect_to_unindent(Input) ->
    collect_to_unindent(Input, "").

collect_to_unindent("", Acc) ->
    {lists:reverse(Acc), ""};

collect_to_unindent([$\n | Rest], Acc) ->
    case re:run(Rest, "^\\S") of
        {match, _} ->
            % Must put the line break back on to detect the next code block.
            {lists:reverse(Acc), [$\n | Rest]};
        nomatch ->
            collect_to_unindent(Rest, [$\n | Acc])
    end;

collect_to_unindent([Char | Rest], Acc) ->
    collect_to_unindent(Rest, [Char | Acc]).
collect_code([$`, $`, $` | Rest]) ->
    % There might be a syntax highlighting hint that we can ignore.
    {_, Rest1} = collect_to_eol(Rest),
    collect_to_fence(Rest1);

collect_code(Input) ->
    collect_to_unindent(Input).
all_code(Input) ->
    all_code(Input, []).

all_code("", Acc) ->
    lists:reverse(Acc);

all_code([$\n, $#, $#, $#, $#, $#, $#, $  | Rest], Acc) ->
    {Name, Rest1} = collect_to_eol(Rest),
    {Code, Rest2} = collect_code(Rest1),
    all_code(Rest2, [{Name, Code} | Acc]);

all_code([_ | Rest], Acc) ->
    all_code(Rest, Acc).
find_indentation("") ->
    "";

find_indentation(Code) ->
    {Line, Rest} = collect_to_eol(Code),
    case re:run(Line, "^(?<white>\\s*)\\S", [{capture, [white], list}]) of
        {match, [White]} ->
            White;
        nomatch ->
            find_indentation(Rest)
    end.
unindent(Code) ->
    case find_indentation(Code) of
        "" ->
            Code;
        Indentation ->
            Pattern = [$^ | Indentation],
            unindent(Code, Pattern, [])
    end.

unindent("", _Pattern, Lines) ->
    string:join(lists:reverse(Lines), "\n");

unindent(Code, Pattern, Lines) ->
    {Line, Rest} = collect_to_eol(Code),
    Unindented_line = re:replace(Line, Pattern, "", [{return, list}]),
    unindent(Rest, Pattern, [Unindented_line | Lines]).
unindent_blocks(Blocks) ->
    lists:map(fun ({Name, Code}) ->
                  {Name, unindent(Code)}
              end,
              Blocks).
concat_blocks(Blocks) ->
    Join_blocks = fun (Key, Acc) ->
        Values = proplists:get_all_values(Key, Blocks),
        Joined = string:join(Values, "\n"),
        [{Key, Joined} | Acc]
    end,

    lists:foldr(Join_blocks, [], proplists:get_keys(Blocks)).
collect_to_macro_delimeter(Line) ->
    collect_to_macro_delimeter(Line, "").

collect_to_macro_delimeter("", Acc) ->
    {lists:reverse(Acc), ""};

% Ignores escaped delimeters.
collect_to_macro_delimeter([$\\, $#, $#, $#, $#, $#, $# | Rest], Acc) ->
    collect_to_macro_delimeter(Rest, [$#, $#, $#, $#, $#, $#, $\\ | Acc]);

collect_to_macro_delimeter([$#, $#, $#, $#, $#, $# | Rest], Acc) ->
    {lists:reverse(Acc), Rest};

collect_to_macro_delimeter([Char | Rest], Acc) ->
    collect_to_macro_delimeter(Rest, [Char | Acc]).
macro(Line) ->
    case collect_to_macro_delimeter(Line) of
        {_, ""} ->
            % No macro in this line.
            nil;

        {Prefix, Rest} ->
            % Rest contains the macro name and, potentially, another
            % delimeter before the suffix.
            {Padded_name, Suffix} = collect_to_macro_delimeter(Rest),
            {string:strip(Padded_name), Prefix, Suffix}
    end.
expand_macros(Code, Blocks) ->
    expand_macros(Code, Blocks, []).

expand_macros("", _Blocks, Acc) ->
    string:join(lists:reverse(Acc), "\n");

expand_macros(Code, Blocks, Acc) ->
    {Line, Rest} = collect_to_eol(Code),
    case macro(Line) of
        nil ->
            expand_macros(Rest, Blocks, [Line | Acc]);

        {Name, Prefix, Suffix} ->
            case proplists:get_value(Name, Blocks) of
                undefined ->
                    io:format("Warning: code block named ~p not found.~n", [Name]),
                    expand_macros(Rest, Blocks, [Line | Acc]);

                Code_to_insert ->
                    New_lines = re:split(Code_to_insert, "\n", [{return, list}]),
                    Wrapped = lists:map(fun (X) -> Prefix ++ X ++ Suffix end, New_lines),
                    expand_macros(Rest, Blocks, [string:join(Wrapped, "\n") | Acc])
            end
    end.
expand_all_macros(Blocks) ->
    expand_all_macros(Blocks, Blocks, []).

expand_all_macros([], _Blocks, Acc) ->
    lists:reverse(Acc);

expand_all_macros([{Name, Code} | Rest], Blocks, Acc) ->
    expand_all_macros(Rest, Blocks, [{Name, expand_macros(Code, Blocks)} | Acc]).

unescape(Code) ->
    re:replace(Code, "\\\\######", "######", [global, {return, list}]).
unescape_blocks(Blocks) ->
    unescape_blocks(Blocks, []).

unescape_blocks([], Acc) ->
    lists:reverse(Acc);

unescape_blocks([{Name, Code} | Rest], Acc) ->
    unescape_blocks(Rest, [{Name, unescape(Code)} | Acc]).
file_blocks(Blocks) ->
    file_blocks(Blocks, []).

file_blocks([], Acc) ->
    lists:reverse(Acc);

file_blocks([{[$f, $i, $l, $e, $: | _] = Name, Code} | Rest], Acc) ->
    file_blocks(Rest, [{Name, Code} | Acc]);

file_blocks([_ | Rest], Acc) ->
    file_blocks(Rest, Acc).
file_name(Base_directory, File_name) ->
    filename:nativename(filename:absname_join(Base_directory, File_name)).

write_file(Base_directory, File_name, Contents) ->
    Fn = file_name(Base_directory, File_name),
    ok = file:write_file(Fn, Contents),
    Fn.
process_file(File_name) ->
    Base_directory = filename:dirname(File_name),
    Files = file_blocks(
                unescape_blocks(
                    expand_all_macros(
                        concat_blocks(
                            unindent_blocks(
                                all_code(
                                    read_file(File_name))))))),
    write_file_blocks(Base_directory, Files).

write_file_blocks(_Base_directory, []) ->
    ok;

write_file_blocks(Base_directory, [{[$f, $i, $l, $e, $: | File_name], Contents} | Rest]) ->
    write_file(Base_directory, File_name, Contents),
    write_file_blocks(Base_directory, Rest).
process_files([]) ->
    ok;

process_files([File | Files]) ->
    process_file(File),
    process_files(Files).
read_file(File_name) ->
    {ok, Binary} = file:read_file(File_name),
    binary_to_list(Binary).

print_blocks(Blocks) ->
    lists:foreach(fun ({Name, Code}) ->
                      io:format("~s~n-----~n~s~n-----~n~n",
                                [Name, Code])
                  end,
                  Blocks).
print_code(File_name) ->
    print_blocks(
        all_code(
            read_file(File_name))).

print_unindented_code(File_name) ->
    print_blocks(
        unindent_blocks(
            all_code(
                read_file(File_name)))).

print_concatenated_code(File_name) ->
    print_blocks(
        concat_blocks(
            unindent_blocks(
                all_code(
                    read_file(File_name))))).

print_expanded_code(File_name) ->
    print_blocks(
        expand_all_macros(
            concat_blocks(
                unindent_blocks(
                    all_code(
                        read_file(File_name)))))).

print_unescaped_code(File_name) ->
    print_blocks(
        unescape_blocks(
            expand_all_macros(
                concat_blocks(
                    unindent_blocks(
                        all_code(
                            read_file(File_name))))))).

print_file_blocks(File_name) ->
    print_blocks(
        file_blocks(
            unescape_blocks(
                expand_all_macros(
                    concat_blocks(
                        unindent_blocks(
                            all_code(
                                read_file(File_name)))))))).

-ifdef(TEST).
collect_to_eol_test() ->
    {"", ""} = collect_to_eol(""),
    {"foo", "bar\nbaz"} = collect_to_eol("foo\nbar\nbaz"),
    {"foo", ""} = collect_to_eol("foo\n").

collect_to_fence_test() ->
    {"foobar", ""} = collect_to_fence("foobar"),
    {"my\ncode\nhere", "\nmore input"} = collect_to_fence("my\ncode\nhere\n```\nmore input").

collect_to_unindent_test() ->
    {"foobar", ""} = collect_to_unindent("foobar"),
    {"    my\n    code\n    here\n", "\nmy documentation"} = collect_to_unindent("    my\n    code\n    here\n\nmy documentation").
fenced_collect_code_test() ->
    Input = "```erlang\n"
            "\n"
            "-module(foobar).\n"
            "-compile(export_all).\n"
            "\n"
            "foo() ->\n"
            "    ok.\n"
            "```\n"
            "\n"
            "documentation\n",
    Expected_block = "\n"
                     "-module(foobar).\n"
                     "-compile(export_all).\n"
                     "\n"
                     "foo() ->\n"
                     "    ok.",
    Expected_rest = "\n\ndocumentation\n",
    {Expected_block, Expected_rest} = collect_code(Input).


indented_collect_code_test() ->
    Input = "\n"
            "    -module(foobar).\n"
            "    -compile(export_all).\n"
            "\n"
            "    foo() ->\n"
            "        ok.\n"
            "\n"
            "documentation\n",
    Expected_block = "\n"
                     "    -module(foobar).\n"
                     "    -compile(export_all).\n"
                     "\n"
                     "    foo() ->\n"
                     "        ok.\n",
    Expected_rest = "\ndocumentation\n",
    {Expected_block, Expected_rest} = collect_code(Input).

all_code_test() ->
    Input = "A sample document.\n"
            "\n"
            "###### indented code block\n"
            "\n"
            "    Code 1, line 1.\n"
            "    Code 1, line 2.\n"
            "\n"
            "More documentation.\n"
            "\n"
            "###### fenced code block\n"
            "```erlang\n"
            "Code 2, line 1.\n"
            "Code 2, line 2.\n"
            "```\n"
            "\n"
            "End of sample document.\n",

    Expected = [{"indented code block", "\n    Code 1, line 1.\n    Code 1, line 2.\n"},
                {"fenced code block", "Code 2, line 1.\nCode 2, line 2."}],

    Expected = all_code(Input).

all_code_no_intermediate_documentation_test() ->
    Input = "A sample document.\n"
            "\n"
            "###### indented code block\n"
            "\n"
            "    Code 1, line 1.\n"
            "    Code 1, line 2.\n"
            "\n"
            "###### another indented code block\n"
            "    Code 2, line 1.\n"
            "    Code 2, line 2.\n"
            "\n"
            "The end.\n",

    Expected = [{"indented code block", "\n    Code 1, line 1.\n    Code 1, line 2.\n"},
                {"another indented code block", "    Code 2, line 1.\n    Code 2, line 2.\n"}],

    Expected = all_code(Input).

find_indentation_test() ->
    "" = find_indentation(""),
    "" = find_indentation("    \n\t  \n    \nsomething"),
    "\t" = find_indentation("\n\n\tsomething\n\n"),
    "    " = find_indentation("\n    something").
unindent_four_spaces_test() ->
    Input = "\n\n    foo() ->\n        ok.\n\n",
    Expected = "\n\nfoo() ->\n    ok.\n",
    Expected = unindent(Input).

unindent_nothing_test() ->
    Input = "\nfoo() ->\n    ok.\n",
    Input = unindent(Input).

unindent_tabs_test() ->
    Input = "\n\tfoo() ->\n\t\tok.\n",
    Expected = "\nfoo() ->\n\tok.",
    Expected = unindent(Input).
unindent_blocks_test() ->
    Input = [{"foo", "\tfoo() ->\n\t\tok."},
             {"bar", "    foo() ->\n        ok."}],

    Expected = [{"foo", "foo() ->\n\tok."},
                {"bar", "foo() ->\n    ok."}],

    Expected = unindent_blocks(Input).

concat_blocks_test() ->
    Input = [{"foo", "FOO"},
             {"bar", "BAR"},
             {"foo", "FOO"}],

    Expected = [{"foo", "FOO\nFOO"},
                {"bar", "BAR"}],

    Expected = concat_blocks(Input).

collect_to_macro_delimeter_test() ->
    {"foobar", ""} = collect_to_macro_delimeter("foobar"),
    {"    ", " my macro"} = collect_to_macro_delimeter("    ###### my macro"),
    {"- ", " my macro ###### -"} = collect_to_macro_delimeter("- ###### my macro ###### -"),
    {"my macro ", " -"} = collect_to_macro_delimeter("my macro ###### -"),
    {"\\###### not a macro", ""} = collect_to_macro_delimeter("\\###### not a macro").
macro_test() ->
    nil = macro("foobar"),
    {"my macro", "    ", ""} = macro("    ###### my macro"),
    {"my macro", "    <li>", "</li>"} = macro("    <li>###### my macro ######</li>").

expand_macros_test() ->
    Input_code = "\n"
                 "start\n"
                 "###### things\n"
                 "- ###### things ###### -\n"
                 "end\n",
    Input_blocks = [{"things", "one\ntwo"}],
    Expected = "\nstart\none\ntwo\n- one -\n- two -\nend",
    Expected = expand_macros(Input_code, Input_blocks).

expand_all_macros_test() ->
    Input = [{"first one", "First.\n###### list of things"},
             {"second one", "This...\n-###### list of things ######-\nis the second."},
             {"All the things!", "###### first one ######\n* ###### second one ###### *\nDone."},
             {"list of things", "one\ntwo"}],

    Expected = [{"first one", "First.\none\ntwo"},
                {"second one", "This...\n-one-\n-two-\nis the second."},
                {"All the things!", "First.\none\ntwo\n* This... *\n* -one- *\n* -two- *\n* is the second. *\nDone."},
                {"list of things", "one\ntwo"}],

    Expected = expand_all_macros(expand_all_macros(Input)).

unescape_test() ->
    "foo\n    ###### not a macro\nbar" = unescape("foo\n    \\###### not a macro\nbar"),
    "- \\###### really not a macro \\###### -" = unescape("- \\\\###### really not a macro \\\\###### -"),
    "###### h6 of another Markdown document ######" = unescape("\\###### h6 of another Markdown document \\######").
unescape_blocks_test() ->
    Input = [{"foo", "\\######"},
             {"bar", "bar"},
             {"baz", "\\###### h6 of another Markdown document \\######"}],

    Expected = [{"foo", "######"},
                {"bar", "bar"},
                {"baz", "###### h6 of another Markdown document ######"}],

    Expected = unescape_blocks(Input).
file_blocks_test() ->
    Input = [{"file:a", "a"},
             {"not a file", "not a file"},
             {"file:b", "b"}],
    Expected = [{"file:a", "a"},
                {"file:b", "b"}],
    Expected = file_blocks(Input).
file_name_test() ->
    "test_files/foobar.txt" = file_name("test_files", "foobar.txt"),
    "/path/to/repository/src/knot.erl" = file_name("/path/to/repository", "src/knot.erl").

write_file_test() ->
    "test_files/test.txt" = write_file("test_files", "test.txt", "write_file_test\n"),
    {ok, <<"write_file_test\n">>} = file:read_file(file_name("test_files", "test.txt")),
    file:delete(file_name("test_files", "test.txt")).

process_file_test() ->
    ok = process_file("test_files/process_file_test.md"),
    Expected = read_file("test_files/process_file_test.js.expected_output"),
    Actual = read_file("test_files/process_file_test.js") ++ "\n",
    io:format("~p~n~p~n", [Expected, Actual]),
    Expected = Actual,
    file:delete("test_files/process_file_test.js").
-endif.