<!-- Knot delimiters: "«" "»" -->
# Docker

I'm going to wrap the Knot tool in a Docker image. I want to support two
different usages: a one-off processing of files and a watcher that will
automatically process when files changes.

It's based on Erlang 18.

###### file:Dockerfile
    FROM erlang:18.3.4

To be able to watch files, I'll use `inotifywait` which is in the
`inotify-tools` package.

###### file:Dockerfile
    RUN apt-get update && \
        apt-get install --assume-yes inotify-tools && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

Knot is written in LFE, so I need to install LFE, add Knot code, and compile
it.

###### file:Dockerfile
    RUN cd /usr/local/lib/erlang/lib && \
        git clone https://github.com/rvirding/lfe.git && \
        cd /usr/local/lib/erlang/lib/lfe && \
        git checkout v1.0 && \
        make compile install

    COPY src /usr/local/lib/erlang/lib/knot/src
    COPY ebin/knot.app /usr/local/lib/erlang/lib/knot/ebin/knot.app
    RUN cd /usr/local/lib/erlang/lib/knot && \
        lfec -o ebin src/*.lfe

Now I need to add an entrypoint that will handle both usages. This will be a
bash script I drop into the image.

###### file:Dockerfile
    COPY ./docker_entrypoint.sh /usr/local/bin
    RUN chmod +x /usr/local/bin/docker_entrypoint.sh
    ENTRYPOINT ["docker_entrypoint.sh"]

###### file:docker_entrypoint.sh
    #!/bin/bash

    usage() {
        echo
        echo "How to Use Knot"
        echo "---------------"
        echo
        echo "«usage instructions»"
        echo
    }

    first_argument=$1

    if [[ $# -le 0 ]]; then
        usage
    elif [ "$first_argument" = "help" ]; then
        usage
    elif [ "$first_argument" = "--help" ]; then
        usage
    elif [ "$first_argument" = "-h" ]; then
        usage

    elif [ "$first_argument" = "watch" ]; then
        shift

        files=$*
        real_files=
        for file in $files; do
            real_files="$real_files $(realpath $file)"
        done

        dirs=$(for file in $files; do
            dirname $file
        done | sort | uniq)
        real_dirs=
        for dir in $dirs; do
            real_dirs="$real_dirs $dir"
        done

        echo "Knot watching directories: \"$dirs\" for files: \"$files\"."

        inotifywait --monitor --event close_write --format '%w%f' $real_dirs | while read file; do
            real_file=$(realpath $file)
            if [[ " ${real_files[@]} " =~ " ${real_file} " ]]; then
                echo "Knot processing: $file"
                lfe -eval "(knot:process-file #\"$real_file\")"
            fi
        done
    else
        command=
        for file in $*; do
            case $file in
                *.md)
                    command="$command (knot:process-file #\"$file\")"
                    ;;
            esac
        done
        lfe -eval "$command"
    fi

In the `else` block I do a one-off processing of a list of files. There's a bit
of a delay (subsecond, but potentially annoying) when Erlang exits so I build
up the command I need to pass to `lfe -eval`.

When watching files it's a bit more complicated because I haven't had much
success watching specific files with `inotifywait`. I don't remember the
details, but the events are different when watching a file that changes versus
an event (for a file) in a watched directory. So -- I watch the directories of
each of the given files. When I get an event I need to then check if that file
is in the given list.

That brings me to two idiosyncrasies. The first deals with [checking for an
element in a list in bash][]. The `=~` operator checks for substrings. Each of
the variable expansions need to be padded with spaces to prevent, for example,
`tests.md` from matching both `tests.md` and `knots_tests.md`.

The second is using `realpath` to normalize the file names. The user might give
`knot.md` but the `%w%f` of inotifywait will give `./knot.md`. Realpath
normalizes them both to `/workdir/knot.md`.

Incidentally, in the Dockerfile I need to define `/workdir` as the workdir.

###### file:Dockerfile
    WORKDIR /workdir

### Usage

These are the instructions for using the image. This is also included as help
to the entrypoint.

###### usage instructions
    To process file(s) once:
        docker run --interactive --tty --rm --volume $(pwd):/workdir mqsoh/knot file1 ...

    To watch file(s) for changes:
        docker run --interactive --tty --rm --volume $(pwd):/workdir mqsoh/knot watch file1 ...

    I recommend a bash function like the following:
        knot() {
            docker run --interactive --tty --rm --volume $(pwd):/workdir mqsoh/knot \"$@\"
        }

    Then using it like this:
        knot file1 ...
        knot watch file1 ...

    If you're using Docker compose, you can include this as container. For
    example, to build Knot I have it running to output source files and another
    container that watches for changes in the source files and compiles them.

        knot:
          image: mqsoh/knot
          volumes:
            - .:/workdir
          command: watch file1 ...

    Documentation about the syntax of Knot files can be found in the README at:

        https://github.com/mqsoh/knot



[checking for an element in a list in bash]: http://stackoverflow.com/a/15394738/8710
