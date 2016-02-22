# Packaging with Docker

I originally wrote knot to require as few dependencies as possible. I wrote it
in Erlang even though I'm more interested in LFE right now. I wrote (bad) code
to poll the file system for the modified times because I didn't want people to
have to install `inotify-tools`.

Docker changes that, so I'm going to distribute Knot as a Docker image. I've
been using tools out of Docker images like this for a little while now and it's
incredibly useful. I don't need to worry about versions anymore and I also
don't need to install miscellaneous tools onto my host system.

###### file:Dockerfile

```{name="file:Dockerfile"}
# This file was generated from packaging_with_docker.knot.md in the GitHub
# repository.
FROM erlang:18

<<Install the Knot script.>>
<<Install inotify-tools.>>
<<Create a wrapper around inofify-tools to watch files.>>
```

I think when I rewrite this as an LFE program, I'll run the code with an `erl`
command, not using an escript/lfescript. The reason is that I have the
impression that the error reporting is better. Since I already distribute Knot
as an escript, I'll use it in the Docker image because it's easiest right now.

###### Install the Knot script.

```{name="Install the Knot script."}
ADD ./knot /usr/local/bin/
RUN chmod +x /usr/local/bin/knot
```

Installing inotify-tools is simple.

###### Install inotify-tools.

```{name="Install inotify-tools."}
RUN apt-get update && \
    apt-get install -y inotify-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
```

It's possible to create a Docker `CMD` that runs the loop to recompile,
however, it's a long one-liner. I'll echo a script in the Dockerfile. Another
option would be to create a file locally and `ADD` it. I don't like that
because it clutters the repository for something that is only used in the
Dockerfile. Also! Using Knot, I can actually make this look relatively nice.

###### Create a wrapper around inofify-tools to watch files.

```{name="Create a wrapper around inofify-tools to watch files."}
RUN echo "#!/bin/bash\n\
<<Watch and recompile Knot files.>>\n\
" > /usr/local/bin/knot-watch && \
chmod +x /usr/local/bin/knot-watch

WORKDIR /workdir

ENTRYPOINT ["knot-watch"]
```

One of the nice things about Knot is that it maintains the prefix and suffix of
the lines on which a code section was defined. That means that any content
I put in `<<Watch and recompile knot files.>>` will have the `\n\` suffix for
each line. So here's the script. It's inside the echo string, so there's some
weird escaping.

(I don't like it that you have to remember the context for these code sections.
It'd be cool to be able to define a function to be able to escape it!)

The `WORKDIR` establishes a convention for the image that the volume should be
mapped to `/workdir`. With `docker run`: the `--volume $(pwd):/workdir`. In an
Docker Compose file, I only need:

    mycontainer:
      image: mqsoh/knot
      volumes:
        - .:/workdir

###### Watch and recompile Knot files.

```{name="Watch and recompile Knot files."}
echo "Watching: \$@"
inotifywait --monitor --event close_write --event delete_self --format '%w%f' \"\$@\" | while read file; do
    case \$file in
        *.knot.md)
            if [ -a "\$file" ]; then
                knot \$file
            fi
            ;;
    esac
done
```

I'm listening to the `close_self` and `delete_self` events. I know from
previous experience that `close_self` is the last event that files generate
when they're saved -- but only when watching a directory! When I watch a
specific file, and when it's saved with vim, I get: `move_self`, `attrib`, and
`delete_self`. I don't know what `delete_self` refers to, but it sounds like
deleting. That's why I've added the check on whether or not the file exists
(`if [ -a "$file" ]; then`). There's a lot of unknowns here, so I expect that
there's a bug.
