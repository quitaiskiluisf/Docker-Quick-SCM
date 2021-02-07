# Docker-Quick-SCM

This docker container provides a server to host GIT and SVN repositores.

Both repositories are made available to git and svn clients through the HTTP protocol using Apache httpd's ``mod_svn`` (for SVN access) and ``mod_cgi`` (using git's built-in http-backend). The files in the repositories are also browseable using a web browser (courtesy of ``mod_svn`` -- for svn repositories -- and ``gitweb`` -- for git).

* Dockerfile available on https://github.com/quitaiskiluisf/Docker-Quick-SCM
* Ready to use image available on https://hub.docker.com/r/quitaiskiluisf/quick-scm

# Usage

```
$ docker run -d -p 8080:80 --name "instance_name" quitaiskiluisf/quick-scm
```

Then, fire up http://localhost:8080 in your web browser to test it.

The repositories are stored in /var/www/repos inside the container, so you will most likely want to mount that location in the container to some other location in your computer. In the following example, the path /var/www/repos inside the container would be bind-mounted to the path /srv/docker-quick-scm/repos on the docker host:

```
$ docker run -d -p 8080:80 -v /srv/docker-quick-scm/repos:/var/www/repos --name "instance_name" quitaiskiluisf/quick-scm
```

Before mouting this volume, make sure that it contains both a ``git-repos`` and a ``svn-repos`` directory. This is where the container will store the git and svn repositories, respectivelly. Also make sure that the user whose ID is 1000 has read and write permissions in both of this locations and to the files in it.

You probably also want to enable authentication for users accessing the repositories. To do so, you may bind-mount to the path /var/www/auth in the container and provide two extra files.

```
$ docker run -d -p 8080:80 -v /srv/docker-quick-scm/repos:/var/www/repos -v /srv/docker-quick-scm/auth:/var/www/auth --name "instance_name" quitaiskiluisf/quick-scm
```

The extra files are the following:

* ``auth.conf``: the content of this file will be loaded inside a ``<Location />`` tag in the sites's configuration section. It may include the authentication options as such:

```
AuthType Basic
AuthName "SCM"
AuthUserFile /var/www/auth/htpasswd
Require valid-user
```

* htpasswd: the file containing the usernames/passwords.

Besides this, you may also want to set the timezone for the container, so that the log messages produced by Apache httpd contain the correct time:

```
$ docker run -d -p 8080:80 -e "TZ=America/Sao_Paulo" -v /srv/docker-quick-scm/repos:/var/www/repos -v /srv/docker-quick-scm/auth:/var/www/auth --name "instance_name" quitaiskiluisf/quick-scm
```
