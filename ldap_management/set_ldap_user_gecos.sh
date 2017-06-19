#!/bin/bash

SCRIPT=$(readlink -f $0)
SCRIPT_PATH=`dirname $SCRIPT`
source ${SCRIPT_PATH}/config.sh
source ${SCRIPT_PATH}/ldap_functions.sh

# Input ${1} -> username, ${2} -> gecos to set

ldap_set_bind_password ${LDAP_BIND_PASS}
ldap_set_user_gecos ${1} ${2}

