#!/usr/bin/env bash

# We want to abort execution on any sort of error and not that it happened, this function is used when an error is trapped
abort() {
    echo >&2 '
***************
*** ABORTED ***
***************
'
    echo "An error occurred. Exiting . . ." >&2
    exit 1
}

process_resource_directory() {
  rpath=$1
  shift

  echo Scanning $rpath ...
  readarray -d '' entries < <(printf '%s\0' $rpath/* | sort -zV)
  for entry in "${entries[@]}"; do
    if [ -d $entry ]; then
      process_resource_directory $entry
    else
      echo Applying $entry.
      microk8s kubectl apply -f $entry > /dev/null
    fi
  done
}

wait_for_pod() {
  namespace=$1
  shift
  pattern=$1
  shift
  # Uncomment this echo below to help debug the result what kubectl get pods command line looks like
#  echo namespace: $namespace app: $pattern
  while [[ $(microk8s kubectl get pods -n $namespace -l $pattern -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n . && sleep 1; done
  echo . Done!
}

#function_name() {
#readarray -d '' entries < <(printf '%s\0' *.fas | sort -zV)
#for entry in "${entries[@]}"; do
#  # do something with $entry
#done
#}
