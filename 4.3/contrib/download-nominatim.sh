#! /bin/bash

ENV CURRENT_VERSION=1.0.0
ENV NOMINATIM_VERSION=4.3.1
ARG USER_AGENT=emaphp/nominatim-nginx-docker:${CURRENT_VERSION}-${NOMINATIM_VERSION}

curl -A $USER_AGENT https://nominatim.org/release/Nominatim-$NOMINATIM_VERSION.tar.bz2 -o nominatim.tar.bz2
