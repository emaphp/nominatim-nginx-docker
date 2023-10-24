#!/bin/bash -ex

# Check if THREADS is not set or is empty
if [ -z "$THREADS" ]; then
    THREADS=$(nproc)
fi

# Prevent asyncpg complaining about credentials
HOME=/nominatim

# Import
cd ${PROJECT_DIR}
if [ "$REVERSE_ONLY" = "true" ]; then
    su -c "nominatim import --osm-file $PBF_PATH --threads $THREADS --reverse-only" -g nominatim nominatim
else
    su -c "nominatim import --osm-file $PBF_PATH --threads $THREADS" -g nominatim nominatim
fi

# Sometimes Nominatim marks parent places to be indexed during the initial
# import which leads to '123 entries are not yet indexed' errors in --check-database
# Thus another quick additional index here for the remaining places
su -c "nominatim index --threads $THREADS" -g nominatim nominatim
su -c "nominatim admin --check-database" -g nominatim nominatim

# gather statistics for query planner to potentially improve query performance
# see, https://github.com/osm-search/Nominatim/issues/1023
# and  https://github.com/osm-search/Nominatim/issues/1139
su -c "psql -d $PGDATABASE -c 'ANALYZE VERBOSE'" -g nominatim nominatim
