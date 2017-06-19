#!/bin/bash

SCRIPT=$(readlink -f $0)
SCRIPT_PATH=`dirname $SCRIPT`
source ${SCRIPT_PATH}/config.sh
source ${SCRIPT_PATH}/ldap_functions.sh

# Input ${1} -> hostname, ${2} -> ipv4 address

ldap_set_bind_password ${LDAP_BIND_PASS}
ldap_add_host ${1} ${2}
