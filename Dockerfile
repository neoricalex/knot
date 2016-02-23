# This file was generated from packaging_with_docker.knot.md in the GitHub
# repository.
FROM erlang:18

ADD ./knot /usr/local/bin/
RUN chmod +x /usr/local/bin/knot
RUN apt-get update && \
    apt-get install -y inotify-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN echo "#!/bin/bash\n\
echo "Watching: \$@"\n\
inotifywait --monitor --event close_write --event delete_self --format '%w%f' \"\$@\" | while read file; do\n\
    case \$file in\n\
        *.md)\n\
            if [ -a "\$file" ]; then\n\
                knot \$file\n\
            fi\n\
            ;;\n\
    esac\n\
done\n\
" > /usr/local/bin/knot-watch && \
chmod +x /usr/local/bin/knot-watch

WORKDIR /workdir

ENTRYPOINT ["knot-watch"]