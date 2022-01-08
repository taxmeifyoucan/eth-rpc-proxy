#!/bin/bash

function count_filter {
  sed '/^[^#]/s/_count /_bucket{le="+Inf"} /'
}

function pull_to_push {
  METRICS_FILTER=count_filter

  curl dshackle:$METRICS_PORT/$METRICS_URL | $METRICS_FILTER > /tmp/opt_metrics

  cat /tmp/opt_metrics |
  curl -v --data-binary @- \
  $PUSHGATEWAY_URL/metrics/job/pushgateway/scrape_location/$SCRAPE_LOCATION/project/$PROJECT_NAME/instance/$INVENTORY_HOSTNAME
}

while [ 1 ]
do
pull_to_push
sleep 10
done


