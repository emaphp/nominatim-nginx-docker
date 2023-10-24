#!/bin/bash -ex

tailpid=0
replicationpid=0

stopServices() {
    service nginx stop
    service php7.4-fpm stop
    kill $replicationpid
    kill $tailpid
}
trap stopServices SIGTERM TERM INT

# Initialize server
cd ${PROJECT_DIR}
su -c "nominatim refresh --website --functions" -g nominatim nominatim

service php7.4-fpm start
service nginx start

# Setup replication
touch /var/log/replication.log
chown nominatim:nominatim /var/log/replication.log
if [ "$NOMINATIM_REPLICATION_URL" != "" ] ; then
    # run init in case replication settings changed
    su -c "nominatim replication --project-dir $PROJECT_DIR --init" -g nominatim nominatim
    if [ "$UPDATE_MODE" == "continuous" ]; then
        echo "starting continuous replication"
        su -c "nominatim replication --project-dir $PROJECT_DIR &> /var/log/replication.log &" -g nominatim nominatim
        replicationpid=${!}
    elif [ "$UPDATE_MODE" == "once" ]; then
        echo "starting replication once"
        su -c "nominatim replication --project-dir $PROJECT_DIR --once &> /var/log/replication.log &" -g nominatim nominatim
        replicationpid=${!}
    elif [ "$UPDATE_MODE" == "catch-up" ]; then
        echo "starting replication once in catch-up mode"
        su -c "nominatim replication --project-dir $PROJECT_DIR --catch-up &> /var/log/replication.log &" -g nominatim nominatim
        replicationpid=${!}
    else
        echo "skipping replication"
    fi
    # TODO: enable freeze
fi

# Send logs
tail -Fv /var/log/nginx/access.log /var/log/nginx/error.log /var/log/replication.log &
tailpid=${!}

# Warm up
if [ "REVERSE_ONLY" = "true" ]; then
    echo "Warm database caches for reverse queries"
    su -c "NOMINATIM_QUERY_TIMEOUT=600 NOMINATIM_REQUEST_TIMEOUT=3600 nominatim admin --warm --reverse" -g nominatim nominatim
else
    echo "Warm database caches for search and reverse queries"
    su -c "NOMINATIM_QUERY_TIMEOUT=600 NOMINATIM_REQUEST_TIMEOUT=3600 nominatim admin --warm" -g nominatim nominatim
fi
echo "Warming finished"

echo "--> Nominatim is ready to accept requests"

wait
