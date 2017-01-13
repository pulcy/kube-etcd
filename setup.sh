#!/bin/bash 

KUBECTL=${KUBECTL_BIN:-/usr/local/bin/kubectl}
KUBECTL_OPTS=${KUBECTL_OPTS:-}
NAMESPACE=${NAMESPACE:-base}

# Remember that you can't log from functions that print some output (because
# logs are also printed on stdout).
# $1 level
# $2 message
function log() {
  # manage log levels manually here

  # add the timestamp if you find it useful
  case $1 in
    DB3 )
#        echo "$1: $2"
        ;;
    DB2 )
#        echo "$1: $2"
        ;;
    DBG )
#        echo "$1: $2"
        ;;
    INFO )
        echo "$1: $2"
        ;;
    WRN )
        echo "$1: $2"
        ;;
    ERR )
        echo "$1: $2"
        ;;
    * )
        echo "INVALID_LOG_LEVEL $1: $2"
        ;;
  esac
}

# $1 command to execute.
# $2 count of tries to execute the command.
# $3 delay in seconds between two consecutive tries
function run_until_success() {
  local -r command=$1
  local tries=$2
  local -r delay=$3
  local -r command_name=$1
  while [ ${tries} -gt 0 ]; do
    log DBG "executing: '$command'"
    # let's give the command as an argument to bash -c, so that we can use
    # && and || inside the command itself
    /bin/bash -c "${command}" && \
      log DB3 "== Successfully executed ${command_name} at $(date -Is) ==" && \
      return 0
    let tries=tries-1
    log WRN "== Failed to execute ${command_name} at $(date -Is). ${tries} tries remaining. =="
    sleep ${delay}
  done
  return 1
}

function install_etcd_operator() {
    run_until_success "${KUBECTL} ${KUBECTL_OPTS} apply --namespace=${NAMESPACE} -f /app/etcd-operator.yaml" 3 5

    if [[ $? -eq 0 ]]; then
        log INFO "== ETCD operator install completed successfully at $(date -Is) =="
    else
        log WRN "== ETCD operator install completed with errors at $(date -Is) =="
    fi
}

function install_etcd_cluster() {
    run_until_success "${KUBECTL} ${KUBECTL_OPTS} create --namespace=${NAMESPACE} -f /app/etcd-cluster.yaml" 60 2

    if [[ $? -eq 0 ]]; then
        log INFO "== ETCD cluster install completed successfully at $(date -Is) =="
    else
        log WRN "== ETCD cluster install completed with errors at $(date -Is) =="
    fi
}

function install_etcd_service() {
    run_until_success "${KUBECTL} ${KUBECTL_OPTS} apply --namespace=${NAMESPACE} -f /app/etcd-service.yaml" 5 5

    if [[ $? -eq 0 ]]; then
        log INFO "== ETCD service install completed successfully at $(date -Is) =="
    else
        log WRN "== ETCD service install completed with errors at $(date -Is) =="
    fi
}


# Wait for the default service account to be created in the kube-system namespace.
token_found=""
while [ -z "${token_found}" ]; do
  sleep .5
  token_found=$(${KUBECTL} ${KUBECTL_OPTS} get --namespace="${NAMESPACE}" serviceaccount default -o go-template="{{with index .secrets 0}}{{.name}}{{end}}")
  if [[ $? -ne 0 ]]; then
    token_found="";
    log WRN "== Error getting default service account, retry in 0.5 second =="
  fi
done
log INFO "== Default service account in the ${SYSTEM_NAMESPACE} namespace has token ${token_found} =="

install_etcd_operator 
sleep 30 
install_etcd_cluster
sleep 15 
install_etcd_service
