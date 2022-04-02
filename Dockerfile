FROM debian:buster-slim

MAINTAINER Luís Fernando Quitaiski (lfernandoq@gmail.com)

RUN apt-get update && \
    apt-get --assume-yes install \
                                 apache2 \
                                 git \
                                 gitweb \
                                 libapache2-mod-svn \
                                 libapache2-mod-wsgi \
                                 python2 \
                                 python-pip \
                                 subversion && \
    # Install Trac and its dependencies
    pip install Trac[babel,rest,pygments,textile] && \
    # Cleaning up files which are not needed anymore
    rm -rf /var/lib/apt/lists/* && \
    # Enable CGI execution (necessary for gitweb)
    a2enmod cgi && \
    # Use file descriptors as log destinations instead of local files
    # This allows the usage of "docker logs" to get the log files from outside
    # the container
    sed -ri \
            -e 's!^(\s*CustomLog)\s+\S+!\1 /proc/self/fd/1!g' \
            -e 's!^(\s*ErrorLog)\s+\S+!\1 /proc/self/fd/2!g' \
            -e 's!^(\s*TransferLog)\s+\S+!\1 /proc/self/fd/1!g' \
            $(find /etc/apache2 -type f -iname "*conf") && \
    # Remove old configuration files and unnecessary files
    rm -rf /etc/apache2/sites-available/*.conf /etc/apache2/sites-enabled/*.conf /var/www/html/* && \
    # Create directories and new configuration files
    mkdir -p /var/www/repos /var/www/auth && \
    # Link the "scm.conf" file in the "sites-enabled" directory. The file does not exist yet,
    # but will be copied there soon
    cd /etc/apache2/sites-enabled/ && \
    ln -s ../sites-available/scm.conf && \
    # gitweb.conf
    sed -ri \
            -e 's!/var/lib/git!/var/www/repos/git-repos!g' \
            -e 's!static/!/git/static/!g' \
            -e 's!^#(@stylesheets)!\1!g' \
            -e 's!^#(\$javascript)!\1!g' \
            -e 's!^#(\$logo)!\1!g' \
            -e 's!^#(\$favicon)!\1!g' \
            /etc/gitweb.conf

COPY scm.conf /etc/apache2/sites-available/

COPY trac.wsgi /var/www/

COPY index.html /var/www/html/

COPY run-apachectl.sh /

EXPOSE 80

CMD ["./run-apachectl.sh"]
