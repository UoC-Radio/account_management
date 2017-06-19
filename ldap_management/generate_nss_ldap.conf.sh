#!/bin/bash

SCRIPT=$(readlink -f $0)
SCRIPT_PATH=`dirname $SCRIPT`
source ${SCRIPT_PATH}/config.sh

# Input: $1 -> Hostname, $2 -> Randomly generated password

cat > ${LDAP_HOSTS_CONF_DIR}/${1}/nss_ldap.conf <<EOF

# Config for nss_ldap
# This usualy goes to /etc/ldap.conf

# Server info
base "${BASE_DN}"
uri ldaps://${LDAP_HOST_IP}
ldap_version 3
scope one
timelimit 2
bind_timelimit 3
bind_policy soft
idle_timelimit 3

# pam_ldap settings
pam_filter objectclass=posixAccount
pam_login_attribute uid
pam_member_attribute memberUid
pam_min_uid ${LDAP_MIN_UID}
pam_password exop

# DNs for NSS loockups
nss_base_passwd	OU=Users,${BASE_DN}
nss_base_shadow	OU=Users,${BASE_DN}
nss_base_group	OU=User Groups,${BASE_DN}
nss_base_hosts	OU=Hosts,${BASE_DN}

# attribute/objectclass mapping
# Syntax:
#nss_map_attribute	rfc2307attribute	mapped_attribute
#nss_map_objectclass	rfc2307objectclass	mapped_objectclass

# Settings to reduce latency
nss_reconnect_tries 1		# number of times to double the sleep time
nss_reconnect_sleeptime 1	# initial sleep value
nss_reconnect_maxsleeptime 1	# max sleep value to cap at
nss_reconnect_maxconntries 3	# how many tries before sleeping

nss_initgroups_ignoreusers ldap,openldap,root,${GLOBAL_USERS}

binddn CN=${1},OU=Hosts,${BASE_DN}
bindpw ${2}

EOF
