# Template rendered by `gu-env init` into a project's compose.yaml.
# Placeholders @@PLUGIN_SLUG@@, @@DEV_THEME@@, @@FIXTURE_PLUGIN_MOUNTS@@,
# @@FIXTURE_THEME_MOUNTS@@ are substituted at init time.
#
# Bring up with:   gu-env up        Tear down:   gu-env down -v
# Run tests with:  gu-env test
#
# Values are interpolated from .env. WordPress core + PHPUnit libs come from
# @wordpress/env's cache (WP_ENV_CACHE_DIR, populated by `wp-env start` once).
#
# Service discovery: the app reaches the database via the host LAN IP
# (HOST_LAN_IP, exported by gu-env) on the mapped DB ports — no sudo / no
# container-name DNS required. For name-based discovery instead, run
# `sudo container system dns create opossum` once and set WORDPRESS_DB_HOST to
# the bare service name (mysql / tests-mysql).

services:
  mysql:
    image: 'mariadb:lts'
    ports:
      - '${WP_ENV_MYSQL_PORT:-3306}:3306'
    environment:
      MYSQL_ROOT_HOST: '%'
      MYSQL_ROOT_PASSWORD: password
      MYSQL_DATABASE: wordpress
    volumes:
      - 'mysql:/var/lib/mysql'
    healthcheck:
      test: ['CMD', 'healthcheck.sh', '--connect', '--innodb_initialized']
      interval: 5s
      timeout: 5s
      retries: 20
      start_period: 30s

  tests-mysql:
    image: 'mariadb:lts'
    ports:
      - '${WP_ENV_TESTS_MYSQL_PORT:-3307}:3306'
    environment:
      MYSQL_ROOT_HOST: '%'
      MYSQL_ROOT_PASSWORD: password
      MYSQL_DATABASE: tests-wordpress
    volumes:
      - 'mysql-test:/var/lib/mysql'
    healthcheck:
      test: ['CMD', 'healthcheck.sh', '--connect', '--innodb_initialized']
      interval: 5s
      timeout: 5s
      retries: 20
      start_period: 30s

  wordpress:
    depends_on:
      - mysql
    build:
      context: .
      dockerfile: docker/WordPress.Dockerfile
      args:
        HOST_USERNAME: ${HOST_USERNAME}
        HOST_UID: '${HOST_UID}'
        HOST_GID: '${HOST_GID}'
        XDEBUG_HOST: '${XDEBUG_HOST}'
    ports:
      - '${WP_ENV_PORT:-8888}:80'
    environment:
      APACHE_RUN_USER: '#${HOST_UID}'
      APACHE_RUN_GROUP: '#${HOST_GID}'
      WORDPRESS_DB_USER: root
      WORDPRESS_DB_PASSWORD: password
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_HOST: '${HOST_LAN_IP}:${WP_ENV_MYSQL_PORT}'
      WORDPRESS_DB_PORT: '${WP_ENV_MYSQL_PORT:-3306}'
      WP_TESTS_DIR: /wordpress-phpunit
    volumes:
      - '${WP_ENV_CACHE_DIR}/WordPress:/var/www/html'
      - '${WP_ENV_CACHE_DIR}/WordPress-PHPUnit/tests/phpunit:/wordpress-phpunit'
      - ${PWD}/.opossum-home/user:/home/${HOST_USERNAME}
      - '${PWD}:/var/www/html/wp-content/plugins/@@PLUGIN_SLUG@@'
      @@FIXTURE_PLUGIN_MOUNTS@@
      @@FIXTURE_THEME_MOUNTS@@

  tests-wordpress:
    depends_on:
      - tests-mysql
    build:
      context: .
      dockerfile: docker/Tests-WordPress.Dockerfile
      args:
        HOST_USERNAME: ${HOST_USERNAME}
        HOST_UID: '${HOST_UID}'
        HOST_GID: '${HOST_GID}'
        XDEBUG_HOST: '${XDEBUG_HOST}'
    ports:
      - '${WP_ENV_TESTS_PORT:-8889}:80'
    environment:
      APACHE_RUN_USER: '#${HOST_UID}'
      APACHE_RUN_GROUP: '#${HOST_GID}'
      WORDPRESS_DB_USER: root
      WORDPRESS_DB_PASSWORD: password
      WORDPRESS_DB_NAME: tests-wordpress
      WORDPRESS_DB_HOST: '${HOST_LAN_IP}:${WP_ENV_TESTS_MYSQL_PORT}'
      WORDPRESS_DB_PORT: '${WP_ENV_TESTS_MYSQL_PORT:-3307}'
      WP_TESTS_DIR: /wordpress-phpunit
    volumes:
      - '${WP_ENV_CACHE_DIR}/tests-WordPress:/var/www/html'
      - '${WP_ENV_CACHE_DIR}/tests-WordPress-PHPUnit/tests/phpunit:/wordpress-phpunit'
      - ${PWD}/.opossum-home/tests-user:/home/${HOST_USERNAME}
      - '${PWD}:/var/www/html/wp-content/plugins/@@PLUGIN_SLUG@@'
      @@FIXTURE_PLUGIN_MOUNTS@@
      @@FIXTURE_THEME_MOUNTS@@

  cli:
    depends_on:
      - wordpress
    build:
      context: .
      dockerfile: docker/CLI.Dockerfile
      args:
        HOST_USERNAME: ${HOST_USERNAME}
        HOST_UID: '${HOST_UID}'
        HOST_GID: '${HOST_GID}'
        XDEBUG_HOST: '${XDEBUG_HOST}'
    volumes:
      - '${WP_ENV_CACHE_DIR}/WordPress:/var/www/html'
      - '${WP_ENV_CACHE_DIR}/WordPress-PHPUnit/tests/phpunit:/wordpress-phpunit'
      - ${PWD}/.opossum-home/user:/home/${HOST_USERNAME}
      - '${PWD}:/var/www/html/wp-content/plugins/@@PLUGIN_SLUG@@'
      @@FIXTURE_PLUGIN_MOUNTS@@
      @@FIXTURE_THEME_MOUNTS@@
    user: '${HOST_UID}:${HOST_GID}'
    environment:
      WORDPRESS_DB_USER: root
      WORDPRESS_DB_PASSWORD: password
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_HOST: '${HOST_LAN_IP}:${WP_ENV_MYSQL_PORT}'
      WORDPRESS_DB_PORT: '${WP_ENV_MYSQL_PORT:-3306}'
      WP_TESTS_DIR: /wordpress-phpunit

  tests-cli:
    depends_on:
      - tests-wordpress
    build:
      context: .
      dockerfile: docker/Tests-CLI.Dockerfile
      args:
        HOST_USERNAME: ${HOST_USERNAME}
        HOST_UID: '${HOST_UID}'
        HOST_GID: '${HOST_GID}'
        XDEBUG_HOST: '${XDEBUG_HOST}'
    volumes:
      - '${WP_ENV_CACHE_DIR}/tests-WordPress:/var/www/html'
      - '${WP_ENV_CACHE_DIR}/tests-WordPress-PHPUnit/tests/phpunit:/wordpress-phpunit'
      - ${PWD}/.opossum-home/tests-user:/home/${HOST_USERNAME}
      - '${PWD}:/var/www/html/wp-content/plugins/@@PLUGIN_SLUG@@'
      @@FIXTURE_PLUGIN_MOUNTS@@
      @@FIXTURE_THEME_MOUNTS@@
    user: '${HOST_UID}:${HOST_GID}'
    environment:
      WORDPRESS_DB_USER: root
      WORDPRESS_DB_PASSWORD: password
      WORDPRESS_DB_NAME: tests-wordpress
      WORDPRESS_DB_HOST: '${HOST_LAN_IP}:${WP_ENV_TESTS_MYSQL_PORT}'
      WORDPRESS_DB_PORT: '${WP_ENV_TESTS_MYSQL_PORT:-3307}'
      WP_TESTS_DIR: /wordpress-phpunit

volumes:
  mysql: {}
  mysql-test: {}
