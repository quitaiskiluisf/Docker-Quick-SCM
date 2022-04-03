# Docker-Quick-SCM

This docker container provides a server to host GIT and SVN repositories and the TRAC ticketing system.

Everything is made available through the HTTP protocol using Apache httpd's ``mod_svn`` (for serving SVN repositories), ``mod_cgi`` (for serving GIT repositories using git's built-in http-backend) and ``mod_wsgi`` (for serving TRAC repositories). The files in the repositories themselves are also browseable using a web browser (courtesy of ``mod_svn`` -- for svn repositories -- ``gitweb`` -- for git).

* Dockerfile available on https://github.com/quitaiskiluisf/Docker-Quick-SCM
* Ready to use image available on https://hub.docker.com/r/quitaiskiluisf/quick-scm

Versions used in this release:

* SVN = 1.10.4
* GIT = 2.20.1
* Apache = 2.4.38
* TRAC = 1.4.3

# Usage

```
$ docker run -d -p 8080:80 --name "instance_name" quitaiskiluisf/quick-scm
```

Then, fire up http://localhost:8080 in your web browser to test it.

The repositories are stored in /var/www/repos inside the container, so you will most likely want to map that container location somewhere in the host filesystem to persist the repositories. In the following example, the path /var/www/repos inside the container would be bind-mounted to the path /srv/docker-quick-scm/repos on the docker host:

```
$ docker run -d -p 8080:80 -v /srv/docker-quick-scm/repos:/var/www/repos --name "instance_name" quitaiskiluisf/quick-scm
```

Before mounting this volume, make sure that it contains directories named ``git-repos``, ``svn-repos`` and ``trac-repos``. There are the directories where the container will store GIT, SVN and TRAC repositories, respectivelly. Also make sure that the user whose ID is 33 has read and write permissions to these directories and to the files in it.

Besides this, you may also want to set the timezone for the container, so that the log messages produced by Apache httpd contain the correct time:

```
$ docker run -d -p 8080:80 -e "TZ=America/Sao_Paulo" -v /srv/docker-quick-scm/repos:/var/www/repos --name "instance_name" quitaiskiluisf/quick-scm
```

# Authentication

You probably want to enable authentication for users accessing the repositories. This is mandatory if you want to use TRAC repositories, and highly desireable for SVN/GIT repositories.

Authentication is provided by Apache's authentication/authorization modules and, as such, all of the options described in Apache's documentation at [https://httpd.apache.org/docs/2.4/howto/auth.html] can be used here.

To enable authentication, you may bind-mount to the path /var/www/auth in the container and provide a file named ``auth.conf``. The content of this file will be loaded inside a ``<Location />`` tag in the sites's configuration section, enabling authentication site-wide.

```
$ docker run -d -p 8080:80 -e "TZ=America/Sao_Paulo" -v /srv/docker-quick-scm/repos:/var/www/repos -v /srv/docker-quick-scm/auth:/var/www/auth --name "instance_name" quitaiskiluisf/quick-scm
```

The content of the ``auth.conf`` may change according to the authentication mechanism in use. You can find some examples in the following sections:

## Basic authentication

To enable basic authentication, include the following in the ``auth.conf`` file.

```
AuthType Basic
AuthName "SCM"
AuthUserFile /var/www/auth/htpasswd
Require valid-user
```

You can run the following command to add users and/or change passwords (replace ``myusername`` with the username you want to create/change password):

```
docker exec -it "instance_name" bash -c "touch /var/www/auth/htpasswd && htpasswd /var/www/auth/htpasswd myusername"
```

# Wrapping up

Below you can find the complete line you can use to start using the container:


```
$ docker run -d -p 8080:80 -e "TZ=America/Sao_Paulo" -v /srv/docker-quick-scm/repos:/var/www/repos -v /srv/docker-quick-scm/auth:/var/www/auth --name "instance_name" quitaiskiluisf/quick-scm
```
