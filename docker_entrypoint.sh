#!/bin/bash

usage() {
    echo
    echo "How to Use Knot"
    echo "---------------"
    echo
    echo "To process file(s) once:"
    echo "    docker run --interactive --tty --rm --volume $(pwd):/workdir mqsoh/knot file1 ..."
    echo ""
    echo "To watch file(s) for changes:"
    echo "    docker run --interactive --tty --rm --volume $(pwd):/workdir mqsoh/knot watch file1 ..."
    echo ""
    echo "I recommend a bash function like the following:"
    echo "    knot() {"
    echo "        docker run --interactive --tty --rm --volume $(pwd):/workdir mqsoh/knot \"$@\""
    echo "    }"
    echo ""
    echo "Then using it like this:"
    echo "    knot file1 ..."
    echo "    knot watch file1 ..."
    echo ""
    echo "If you're using Docker compose, you can include this as container. For"
    echo "example, to build Knot I have it running to output source files and another"
    echo "container that watches for changes in the source files and compiles them."
    echo ""
    echo "    knot:"
    echo "      image: mqsoh/knot"
    echo "      volumes:"
    echo "        - .:/workdir"
    echo "      command: watch file1 ..."
    echo ""
    echo "Documentation about the syntax of Knot files can be found in the README at:"
    echo ""
    echo "    https://github.com/mqsoh/knot"
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