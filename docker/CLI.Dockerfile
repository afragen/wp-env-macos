FROM wordpress:cli-php8.2

# Switch to root so we can create users.
USER root

# Create the host's user so that we can match ownership in the container.
ARG HOST_USERNAME
ARG HOST_UID
ARG HOST_GID
ARG XDEBUG_HOST
# When the IDs are already in use we can still safely move on.
RUN addgroup -g $HOST_GID $HOST_USERNAME || true
RUN adduser -h /home/$HOST_USERNAME -G $( getent group $HOST_GID | cut -d: -f1 ) -u $HOST_UID $HOST_USERNAME || true

# Install any dependencies we need in the container.

# Make sure we're working with the latest packages.
RUN apk update

# Install some basic PHP dependencies.
RUN apk --no-cache add $PHPIZE_DEPS && touch /usr/local/etc/php/php.ini

# Set up sudo so they can have root access.
RUN apk --no-cache add sudo linux-headers
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

# Switch back to the original user now that we're done.
USER www-data

# Have the container sleep infinitely to keep it alive for us to run commands on it.
CMD [ "/bin/sh", "-c", "while true; do sleep 2073600; done" ]
