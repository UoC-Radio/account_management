#!/bin/bash

SCRIPT=$(readlink -f $0)
SCRIPT_PATH=`dirname $SCRIPT`
source ${SCRIPT_PATH}/config.sh
source ${SCRIPT_PATH}/ldap_functions.sh

ldap_set_bind_password ${LDAP_BIND_PASS}
ldap_setup_init
