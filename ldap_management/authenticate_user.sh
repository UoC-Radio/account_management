#!/bin/bash

SCRIPT=$(readlink -f $0)
SCRIPT_PATH=`dirname $SCRIPT`
source ${SCRIPT_PATH}/config.sh
BIND_DN="cn=${1},ou=Users,${BASE_DN}"
source ${SCRIPT_PATH}/ldap_functions.sh

# Input: ${1} -> username, asks for user's password

ldap_ask_bind_password
ldap_lookup_user ${1}
