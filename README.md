# Nominatim + Nginx + PHP-FPM Docker Image #

## About ##

A customizable [Nominatim](https://nominatim.org/) Docker image packed with Nginx and PHP-FPM.

This docker image is based on [nominatim-docker](https://github.com/mediagis/nominatim-docker) but adds the following changes:

 - `nginx` instead of `apache2`.
 - `debian:bookworm-slim` as base image.
 - 2 modes of execution: *import* and *server*.
 - Container running `postgis` must be provided separately (check `contrib/docker-compose.yml`).
 - PHP packages provided by [SURY](https://deb.sury.org/).
 - `nginx` and `php-fpm` configuration files included.
 - Customizable `postgis` configuration file for *import* mode.
 - Loads `.pbf` files locally by default.
 - Value `NOMINATIM_IMPORT_STYLE` is set to `extratags` by default.

You can also find this image in [Docker Hub](https://hub.docker.com/r/emaphp/nominatim-nginx-docker). Check the [Versioning](#Versioning) section for details.

## Setup ##

This guide assumes you have *Docker Compose* installed on your system.

This setup will build an image using the latest release of *Nominatim*, which at the time is `4.3`. Clone the repo and setup the environment:

```
 $ git clone //
 $ cd 4.3/
 $ cp contrib/env .env
 $ cp contrib/docker-compose.yml .
```

### PostGIS ###

This setup assumes you will be providing a compatible version of *PostGIS* running on a separate container. This container will be using the following environment variables:

 - `POSTGIS_VERSION`: The version of PostGIS to run. Must be an existing tag of `postgis/postgis` (default: `14-3.4-alpine`)
 - `POSTGIS_CONTAINER_NAME`: The container name. Useful for routing (default: `postgis`)
 - `POSTGIS_PORT`: The port to expose. Notice that you might want to prevent to expose any port in a production setup (default: `5432`).
 - `POSTGIS_DB`: Database name (default: `nominatim`).
 - `POSTGIS_USER`: Database main user (default: `nominatim`).
 - `POSTGIS_PASSWORD`: Database main user password (default: `nominatim`).
 - `POSTGIS_ADMIN_USER`: Additional admin user (default: `admin`)
 - `POSTGIS_ADMIN_PASSWORD`: Additional admin user password (default: `admin`)
 - `POSTGIS_RO_USER`: Read-only user (default: `www-data`).
 - `POSTGIS_RO_PASSWORD`: Read-only user password (default: `www-data`).

Once you finished customizing those values, start the container:

```
 $ docker compose up -d postgis
```

The container will start by creating the database and the user accounts you specified. This is done by running the script located at `postgis/init-postgis.sh`. Once the process is finished, `postgis` will be ready to accept connections.

### Nominatim ###

The main container provides the environment for running `nominatim` and its responsible for both the import process and the server initialization.

Here's a few of the things the container will be doing during the build process:

 - Nominatim will be downloaded, compiled and installed.
 - A user (and group) `nominatim` will be created.
 - Both Nginx and PHP-FPM will be installed. Configuration files will be copied to the container.

Environment variables can be organized by section. Some of them will only take effect during the `import` or `server` processes.

#### Building ####

 - `NOMINATIM_PUID`: The `nominatim` user id (default: `1000`).
 - `NOMINATIM_PGID`: The `nominatim` group id (default: `1000`).
 - `NOMINATIM_USER_PASSWORD`: The `nominatim` user password (default: `nominatim`)

#### PostGIS ####

 - `NOMINATIM_DATABASE_DSN`: Connection string to `postgis`.
 - `NOMINATIM_POSTGIS_HOST`: Database host. Should be equal to `POSTGIS_CONTAINER_NAME`.
 - `NOMINATIM_POSTGIS_DB`: Database name. Should be equal to `POSTGIS_DB`.
 - `NOMINATIM_POSTGIS_USER`: Database user. Should be equal to `POSTGIS_ADMIN_USER`.
 - `NOMINATIM_POSTGIS_PASSWORD`: Database password. Should be equal to `POSTGIS_ADMIN_PASSWORD`.

#### Import ####

These values are only evaluated when running the container in *import* mode.

 - `NOMINATIM_PBF_PATH`: The full path to the `.pbf` file to import (default: `/app/data/pbf/monaco-latest.osm.pbf`)

#### Replication ####

The replication process is setup when running the container in *server* mode. If no replication is necessary, leave `NOMINATIM_REPLICATION_URL` empty.

 - `NOMINATIM_REPLICATION_URL`: The URL to fetch updates from (default: `https://download.geofabrik.de/europe/monaco-updates/`).
 - `NOMINATIM_UPDATE_MODE`: The update mode (default: `continuous`).

#### Server ####

 - `NOMINATIM_CONTAINER_NAME`: Name of the container running `nominatim` (default: `nominatim`).
 - `NOMINATIM_PORT`: The port to expose (default: `8080`).

#### Environment file ####

Additional environment variables are provided using the Nominatim environment file located in `nominatim/config/env`. This file should be used for values that are exclusive to Nominatim and are not meant to be modified regularly. This is done to avoid populating the container environment with values that don't change too often.

## Building the image ##

Build the container by running the following:

```
 $ docker compose build nominatim
```

## Running the container ##

First, make sure the `postgis` container is running and its health status reports `healthy`.

```
 $ docker compose ps
```

As explained earlier, this container can run in 2 modes: *import* mode and *server* mode. This is done by specifying the `command` attribute in the container configuration provided in `docker-compose.yml`. By default, 2 scripts are provided:

 - `scripts/import.sh`: Responsible for importing the data from the `.pbf` files from `nominatim/pbf` to PostGIS.
 - `scripts/runserver.sh`: Sets up the replication process and starts the webserver.

You're free to change or add as many scripts as you want in case the default ones don't really scale to your requirements.

### Importing from PBF ###

By default, the `nominatim` container will run in *import* mode. This process will import the file indicated by `NOMINATIM_PBF_PATH` to the `postgis` container.

```
 $ docker compose up nominatim
```

If everything went ok, the process will finish with an exit code of `0`.

### Running the server ###

Stop all services.

```
 $ docker compose down
```

Comment the line that applies the import configuration on the `postgis` service:

```
      # - ./postgis/postgresql.import.conf:/usr/local/share/postgresql/postgresql.conf.sample
```

You can now apply a different configuration to the `postgis` container. A modified configuration is provided in `postgis/postgresql.tuning.conf` including values suggested in the [Nominatim documentation](https://nominatim.org/release-docs/4.3/admin/Installation/#tuning-the-postgresql-database).

Restart the container:

```
 $ docker compose up -d postgis
```

To run `nominatim` in *server* mode, change the line in the `nominatim` service that looks like this:

```
    command: ["/app/scripts/import.sh"]
```

So it looks like this:

```
    command: ["/app/scripts/runserver.sh"]
```

Start `nominatim`:

```
 $ docker compose up -d nominatim
```

By default, Nominatim will be running on port `8080`. Open a browser tab pointing to http://localhost:8080/status to verify that the server os working.

## Versioning ##

Image tags are a combination of a `release` version and the corresponding `nominatim` version. The `release` version keeps track of fixes and improvements made to the build process but can also be affected by newer releases of `nominatim`.

Here's a full list to check which version is adequate for your system:

| Version     | Release | Nominatim | PHP |
|-------------|---------|-----------|-----|
| 1.0.0-4.3.1 | 1.0.0   | 4.3.1     | 7.4 |

