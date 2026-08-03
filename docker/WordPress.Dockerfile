ARG PHP_VERSION=8.2
FROM wordpress:php${PHP_VERSION}

# Update apt sources for archived versions of Debian.

# stretch (https://lists.debian.org/debian-devel-announce/2023/03/msg00006.html)
RUN touch /etc/apt/sources.list
RUN sed -i 's|deb.debian.org/debian stretch|archive.debian.org/debian stretch|g' /etc/apt/sources.list
RUN sed -i 's|security.debian.org/debian-security stretch|archive.debian.org/debian-security stretch|g' /etc/apt/sources.list
RUN sed -i '/stretch-updates/d' /etc/apt/sources.list

# buster (https://lists.debian.org/debian-devel-announce/2025/06/msg00001.html)
RUN sed -i 's|deb.debian.org/debian buster|archive.debian.org/debian buster|g' /etc/apt/sources.list
RUN sed -i 's|security.debian.org/debian-security buster/updates|archive.debian.org/debian-security buster/updates|g' /etc/apt/sources.list
RUN sed -i '/buster-updates/d' /etc/apt/sources.list

# Create the host's user so that we can match ownership in the container.
ARG HOST_USERNAME
ARG HOST_UID
ARG HOST_GID
ARG XDEBUG_HOST
# When the IDs are already in use we can still safely move on.
RUN groupadd -o -g $HOST_GID $HOST_USERNAME || true
RUN useradd -mlo -u $HOST_UID -g $HOST_GID $HOST_USERNAME || true

# Install any dependencies we need in the container.

# Make sure we're working with the latest packages.
RUN apt-get clean
RUN apt-get -qy update

# Install some basic PHP dependencies.
RUN apt-get -qy install $PHPIZE_DEPS && touch /usr/local/etc/php/php.ini

# Install git
RUN apt-get -qy install git

# Set up sudo so they can have root access.
RUN apt-get -qy install sudo
RUN echo "#$HOST_UID ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
RUN if [ -z "$(pecl list | grep xdebug)" ] ; then pecl install xdebug ; fi
RUN docker-php-ext-enable xdebug
RUN echo 'xdebug.start_with_request=yes' >> /usr/local/etc/php/php.ini
RUN echo 'xdebug.mode=coverage' >> /usr/local/etc/php/php.ini
RUN echo 'xdebug.client_host="${XDEBUG_HOST:-127.0.0.1}"' >> /usr/local/etc/php/php.ini
RUN echo 'upload_max_filesize = 1G' >> /usr/local/etc/php/php.ini
RUN echo 'post_max_size = 1G' >> /usr/local/etc/php/php.ini
RUN curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
RUN export COMPOSER_HASH=`curl -sS https://composer.github.io/installer.sig` && php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '$COMPOSER_HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('/tmp/composer-setup.php'); } echo PHP_EOL;"
RUN php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
RUN rm /tmp/composer-setup.php
USER $HOST_UID:$HOST_GID
ENV PATH="${PATH}:/home/$HOST_USERNAME/.composer/vendor/bin"
RUN composer global require --dev phpunit/phpunit:"^5.7.21 || ^6.0 || ^7.0 || ^8.0 || ^9.0 || ^10.0"
USER root