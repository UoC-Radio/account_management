#!/bin/bash

SCRIPT=$(readlink -f $0)
SCRIPT_PATH=`dirname $SCRIPT`
source ${SCRIPT_PATH}/config.sh

# Input: $1 -> Hostname

cat > ${LDAP_HOSTS_CONF_DIR}/${1}/ldap.conf <<EOF

#
# LDAP Defaults
#

# This file is usualy in /etc/openldap/ldap.conf

# See ldap.conf(5) for details
# This file should be world readable but not world writable.

BASE    ${BASE_DN}
URI     ldaps://${LDAP_HOST_IP}:636

#SIZELIMIT      12
#TIMELIMIT      15
#DEREF          never

TLS_REQCERT allow

EOF
