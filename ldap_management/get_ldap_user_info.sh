#!/bin/bash

SCRIPT=$(readlink -f $0)
SCRIPT_PATH=`dirname $SCRIPT`
source ${SCRIPT_PATH}/config.sh
source ${SCRIPT_PATH}/ldap_functions.sh

# Input: ${1} -> username

ldap_set_bind_password ${LDAP_BIND_PASS}
ldap_get_user_info ${1}

echo "Username: ${1}"
echo "Mail: ${LDAP_USER_MAIL}"
echo "Mobile: ${LDAP_USER_MOBILE}"
echo "Gecos: ${LDAP_USER_GECOS}"
if [[ ${LDAP_USER_EXPIRED} = 1 ]] ; then
	echo "User is expired"
else
	echo "User is active"
fi

ldap_clear_last_user_info
