FROM debian:buster-slim

MAINTAINER Luís Fernando Quitaiski (lfernandoq@gmail.com)

RUN apt-get update && \
    apt-get --assume-yes install apache2 && \
    rm -rf /var/lib/apt/lists/* && \
    # Use file descriptors as log destinations instead of local files
    # This allows the usage of "docker logs" to get the log files from outside
    # the container
    sed -ri \
            -e 's!^(\s*CustomLog)\s+\S+!\1 /proc/self/fd/1!g' \
            -e 's!^(\s*ErrorLog)\s+\S+!\1 /proc/self/fd/2!g' \
            -e 's!^(\s*TransferLog)\s+\S+!\1 /proc/self/fd/1!g' \
            $(find /etc/apache2 -type f -iname "*conf")

# https://httpd.apache.org/docs/2.4/stopping.html#gracefulstop
STOPSIGNAL SIGWINCH

EXPOSE 80

CMD ["apachectl", "-D", "FOREGROUND"]
