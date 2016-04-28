# Knot

Knot is a [literate programming][] tool. Unlike other tools, Knot only
generates source code ('tangling'). By using Markdown for syntax, I believe I
can eliminate the need for the generation of formatted documentation
('weaving'). Repository hosts do a decent job of formatting readable Markdown
and, since they do it automatically, eliminating weaving may actually make
collaboration easier.



# Contents

-   [Usage](#usage)
-   [Syntax](#syntax)
-   [About This Code](#about-this-code)
-   [About Literate Programming](#about-literate-programming)
    -   [Practical Experience](#practical-experience)
    -   [Adoption in Large Projects](#adoption-in-large-projects)



# Usage

I've bundled Knot in a Docker image. Here's a simple Bash function to use Knot.

    knot() {
        docker run --interactive --tty --rm --volume $(pwd):/workdir mqsoh/knot "$@"
    }

Then you can process files once with `knot file1.md ...` and automatically
re-process when files change with `knot watch file1.md ...`.



# Syntax

Knot parses Markdown code blocks -- both the indented and fenced versions.

-   Code blocks must be named; to name a code block, precede it with an H6 with
    the leading `#` style.

-   If a code block's name starts with `file:` then a file will be written with
    the contents of the code block.

-   A code block can contain a reference to another code block. By default the
    delimiters are `<<` and `>>`. The contents of the referenced code block are
    inserted.

-   When inserting lines, the prefix and suffix of the reference are maintained
    for each line -- including indentation!. (This is unique to Knot. I haven't
    seen other tools do this.)

Here's an example that does everything.

    # My Literate Program

    First I'll describe the problem I want to solve, link to other solutions,
    and explain why they aren't good enough.

    My files will contain a list of things enumerated in an indented code
    block.

    ###### My List of Things
        thing 1
        thing 2
        thing 3

    I want to include an HTML file with this list of things. This will be in a
    fenced code block.

    ###### file:htdocs/index.html
    ```
    <!doctype html>
    <title>My List of Things</title>
    <ul>
        <li><<My List of Things>></li>
    </ul>
    ```

    I also want to provide a JavaScript file to annoy users with my list.

    ###### file:js/global.js
        (function () {
            alert("<<My List of Things>>");
        }());

Knot will generate two files from this program: `htdocs/index.html` and
`js/global.js`. The contents will look like the following.

###### htdocs/index.html
    <!doctype html>
    <title>My List of Things</title>
    <ul>
        <li>thing 1</li>
        <li>thing 2</li>
        <li>thing 3</li>
    </ul>

###### js/global.js
    (function () {
        alert("thing 1");
        alert("thing 2");
        alert("thing 3");
    }());



# About This Code

Knot is self hosting, so you can read your first literate program right here. I
think of each document as a chapter in an incredibly small book about my program.

-   [The main program][] &mdash; Processes text and outputs files.
-   [Docker][] &mdash; How this tool was packaged in a Docker image.
-   [An OTP application][] &mdash; A wrapper around the main program that puts
    Knot in a supervision tree. (Not used yet.)

Knot is written in [Lisp Flavoured Erlang (LFE)][].



# About Literate Programming

A great way to start with literate programming is to change your perspective a
little. Right now you're writing code with comments -- try instead to write
documentation with some code! A good example of this is literate CoffeScript.
The code blocks are inserted, in order, into a compiled version of the literate
program.

That works out fine but you're still describing your logic in the order
required by the computer. With a true literate programming tool you can
describe things in any order. When someone reads your code, you want them to
get to the meat of matter immediately. Instead of many lines of imports and
other boilerplate, describe your algorithm immediately and provide the code for
it. Then, at the end of your document, you can wrap it up in the boilerplate.

The other literate programming tools I've used have a one-to-one relationship
of the literate program and the source code. (For example, `my_program.nw`
compiles to `my_program.c`.) I think literate programming can also help
abstract platform boilerplate. In Erlang, most OTP applications need:

- a `.app` file,
- an application callback module, and
- a supervisor callback module.

These files often have about five lines and are tightly coupled. After that you
need another module with your actual code. Why not put this code in one place?
[I did.][]

### Practical Experience

It's not easy to be in expository mode the entire time you're writing code.
I've written a literate program at work for a project on which I was the only
developer. Writing for eight hours a day wrecked me in the beginning. It got a
little bit easier after a while. However, I still fight the temptation to let
that working code I just spent an hour debugging sit there without explanation.

When working on personal projects at home, literate programming is a joy. It's
much, much easier to come back to a literate programming in a week or month and
spent 15 minutes improving it.

An interesting consequence of literate programming: I actually don't care about
syntax highlighting anymore! I usually turn it off entirely.

### Adoption in Large Projects

So... What about large projects? How can a team of five, ten, twenty
collaborate on literate programs? I have no idea! I think it can work because:

- Literate programming is a great way to keep relevant business requirements.
- Describing your code well is a great way to encapsulate conversations that
  might otherwise happen in pull requests.
- It promotes a perspective that will encourage flatter hierarchies and
  *actually* defining dependencies in one place. (In my professional
  experience, we often fail at this.)



[literate programming]: https://en.wikipedia.org/wiki/Literate_programming
[I did.]: ./knot_application.md
[The main program]: ./knot.md
[Docker]: ./docker.md
[An OTP application]: ./knot_application.md
[Lisp Flavoured Erlang (LFE)]: http://lfe.io/
