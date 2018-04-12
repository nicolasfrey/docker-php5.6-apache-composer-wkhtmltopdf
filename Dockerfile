FROM php:5.6-apache

ENV TZ=Europe/Paris
# Set Server timezone.
RUN echo $TZ > /etc/timezone
RUN dpkg-reconfigure -f noninteractive tzdata
RUN echo date.timezone = $TZ > /usr/local/etc/php/conf.d/docker-php-ext-timezone.ini

RUN apt-get -y update
# RUN apt-get -y update && apt-get -y upgrade
RUN apt-get -y update --fix-missing
RUN apt-get install -y --no-install-recommends \
    libmemcached11 \
    libmemcachedutil2 \
    libmemcached-dev \
    libz-dev \
    build-essential \
    apache2-utils \
    libmagickwand-dev \
    imagemagick \
    libcurl4-openssl-dev \
    libssl-dev \
    libc-client2007e-dev \
    libkrb5-dev \
    libmcrypt-dev \
    unixodbc-dev \
    ssmtp \
    vim \
    zlib1g-dev \
    libicu-dev \
    g++ \
    default-jre

# Install wkhtmltopdf
RUN apt-get install -y --no-install-recommends libxrender1 libfontconfig
ADD https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.4/wkhtmltox-0.12.4_linux-generic-amd64.tar.xz /tmp
RUN tar xvJf /tmp/wkhtmltox-0.12.4_linux-generic-amd64.tar.xz -C /tmp
RUN cp /tmp/wkhtmltox/bin/wk* /usr/local/bin/

# Install lib xvfb-run pour la generation des pdf
RUN apt-get install -y --no-install-recommends xvfb xfonts-100dpi xfonts-75dpi xfonts-scalable xfonts-cyrillic xauth

# Config Extension
RUN docker-php-ext-configure gd --with-jpeg-dir=/usr/lib \
    && docker-php-ext-configure imap --with-imap-ssl --with-kerberos \
    && docker-php-ext-configure intl \
    && docker-php-ext-configure pdo_odbc --with-pdo-odbc=unixODBC,/usr

# Install Extension mysqli mysql mbstring opcache pdo_mysql gd mcrypt zip imap bcmath soap pdo intl
RUN docker-php-ext-install mysqli mysql mbstring opcache pdo_mysql gd mcrypt zip imap soap pdo pdo_odbc intl

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Memcache
RUN pecl install memcached-2.2.0
RUN docker-php-ext-enable memcached opcache

# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=256'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
		echo 'opcache.enable=1'; \
	} > /usr/local/etc/php/conf.d/docker-opcache-recommended.ini

# set recommended PHP.ini settings
RUN { \
        echo 'error_reporting  =  E_ALL'; \
        echo 'short_open_tag = Off'; \
        echo 'log_errors = On'; \
        echo 'error_log = /proc/self/fd/2'; \
        echo 'display_errors = Off'; \
        echo 'memory_limit = 2048M'; \
        echo 'date.timezone = Europe/Paris'; \
        echo 'max_execution_time = 300'; \
        echo 'max_input_time = 300'; \
        echo 'memory_limit = -1'; \
        echo 'upload_max_filesize  = 50M'; \
    } > /usr/local/etc/php/conf.d/docker-php.ini


# Imagick
RUN pecl install imagick
RUN docker-php-ext-enable imagick
RUN chown -R www-data:www-data /var/www

# Set up composer variables
ENV COMPOSER_BINARY=/usr/local/bin/composer \
    COMPOSER_HOME=/usr/local/composer
ENV PATH $PATH:$COMPOSER_HOME

# Install composer system-wide
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar $COMPOSER_BINARY && \
    chmod +x $COMPOSER_BINARY

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create Volume
VOLUME ['/etc/apache2/sites-enabled','/var/www/html']

WORKDIR /var/www/html

EXPOSE 80