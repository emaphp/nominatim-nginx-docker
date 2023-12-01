FROM debian:bookworm-slim AS build

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

USER root

WORKDIR /app

RUN true \
    # Update and install all required packages
    && apt-get -y update -qq \
    && apt-get install --no-install-recommends --no-install-suggests -q -y \
        locales \
        locales-all \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && apt-get install -q -y \
        --no-install-recommends \
        --no-install-suggests \
        # Build tools from sources
        build-essential \
        cmake \
        libpq-dev \
        zlib1g-dev \
        libbz2-dev \
        libproj-dev \
        libexpat1-dev \
        libboost-dev \
        libboost-system-dev \
        libboost-filesystem-dev \
        liblua5.4-dev \
        nlohmann-json3-dev \
        # PHP
        php-cli \
        php-cgi \
        # Python
        python3-dev \
        python3-pip \
        python3-tidylib \
        python3-psycopg2 \
        python3-setuptools \
        python3-dotenv \
        python3-psutil \
        python3-jinja2 \
        python3-datrie \
        python3-icu \
        python3-argparse-manpage \
        pyosmium \
        # Extras
        git \
        curl

# Nominatim install
ENV CURRENT_VERSION=1.0.1
ENV NOMINATIM_VERSION=4.3.2
ARG USER_AGENT=emaphp/nominatim-nginx-docker:${CURRENT_VERSION}-${NOMINATIM_VERSION}

# Copy patch to avoid database creation during import process
COPY nominatim/patches/skip-db-creation.patch /app/skip-db-creation.patch

# Build Nominatim
RUN true \
    && curl -A $USER_AGENT https://nominatim.org/release/Nominatim-$NOMINATIM_VERSION.tar.bz2 -o nominatim.tar.bz2 \
    && tar xf nominatim.tar.bz2 \
    && cd Nominatim-$NOMINATIM_VERSION \
    && git apply /app/skip-db-creation.patch \
    && cd /app \
    && mkdir build \
    && cd build \
    && cmake ../Nominatim-$NOMINATIM_VERSION \
    && make -j`nproc` \
    && make install

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Copy compiled files
COPY --from=build /usr/local/bin/nominatim /usr/local/bin/nominatim
COPY --from=build /usr/local/share/nominatim /usr/local/share/nominatim
COPY --from=build /usr/local/lib/nominatim /usr/local/lib/nominatim
COPY --from=build /usr/local/etc/nominatim /usr/local/etc/nominatim
COPY --from=build /usr/local/share/munin/plugins/nominatim_* /usr/local/share/munin/plugins/

# Create nominatim user
USER root

ARG PUID=1000
ENV PUID ${PUID}
ARG PGID=1000
ENV PGID ${PGID}
ARG USER_PASSWORD nominatim
ENV USER_PASSWORD ${USER_PASSWORD}

RUN set -xe; \
    groupadd -g ${PGID} nominatim && \
    useradd -l -u ${PUID} -g nominatim -m nominatim && \
    usermod -p ${USER_PASSWORD} nominatim -s /bin/bash

# Install PHP 7.4 using SURY repo
RUN true \
    && apt-get -y update -qq \
    && apt-get install --no-install-recommends --no-install-suggests -q -y \
       gnupg2 \
       dirmngr \
       curl \
       apt-transport-https \
       lsb-release \
       ca-certificates \
       software-properties-common \
    && apt-key adv --no-tty --keyserver keyserver.ubuntu.com --recv-keys 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62 \
    && curl -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
    && echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list \
    && echo "deb https://nginx.org/packages/mainline/debian/ $(lsb_release -sc) nginx" >> /etc/apt/sources.list

RUN true \
    # Install deps
    && apt-get -y update -qq \
    && apt-get install --no-install-recommends --no-install-suggests -q -y \
        locales \
        locales-all \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && apt-get install -q -y \
        --no-install-recommends \
        --no-install-suggests \
        # Nginx
        nginx \
        # PHP
        php7.4-intl \
        php7.4-pgsql \
        php7.4-cli \
        php7.4-fpm \
        # Runtime dependencies
        libproj25 \
        libboost-filesystem1.74.0 \
        liblua5.4-0 \
        # PostgreSQL client
        postgresql-client-15 \
        postgresql-client-common \
        postgresql-common \
        # Python 3
        python3-tidylib \
        python3-psycopg2 \
        python3-setuptools \
        python3-dotenv \
        python3-psutil \
        python3-datrie \
        python3-icu \
        python3-argparse-manpage \
        python3-jinja2 \
        python3-yaml \
        pyosmium \
        python3-sqlalchemy \
        python3-asyncpg \
    && chown -R nginx:nginx /etc/nginx /etc/php/7.4/fpm /etc/php/7.4/cli \
    && rm /usr/share/nginx/html/* \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Nginx configuration
COPY nominatim/nginx/www.conf /etc/php/7.4/fpm/pool.d/www.conf
COPY nominatim/nginx/default.conf /etc/nginx/conf.d/default.conf

# PHP-FPM configuration
COPY nominatim/php-fpm /etc/php/7.4/fpm/
COPY nominatim/php-fpm/php.ini /etc/php/7.4/cli/

# Setup project directory
ENV PROJECT_DIR=/nominatim

WORKDIR /app

USER root

RUN true \
    && mkdir -p ${PROJECT_DIR} \
    && chown -R nominatim:nominatim ${PROJECT_DIR}

EXPOSE 8080
