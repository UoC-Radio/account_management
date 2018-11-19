#!/bin/bash

SCRIPT=$(readlink -f $0)
SCRIPT_PATH=`dirname $SCRIPT`
source ${SCRIPT_PATH}/config.sh

SUBNET_REGEXP=$(echo ${LOCAL_SUBNET} | awk -F"." '{print $1"\\."$2"\\."$3"\\..*"}')
HOSTNAME_REGEXP=".*\."$(echo "${ROOT_DOMAIN}" | sed 's/\./\\./g')
cat > ${LDAP_CONF_DIR}/slapd.conf <<EOF

#
# See slapd.conf(5) for details on configuration options.
# This file should NOT be world readable.
#
include		${LDAP_CONF_DIR}/schema/core.schema
include		${LDAP_CONF_DIR}/schema/cosine.schema
include		${LDAP_CONF_DIR}/schema/inetorgperson.schema
include		${LDAP_CONF_DIR}/schema/nis.schema
include		${LDAP_CONF_DIR}/schema/misc.schema
include		${LDAP_CONF_DIR}/schema/uoc-radio.schema

# Define global ACLs to disable default read access.

# Do not enable referrals until AFTER you have a working directory
# service AND an understanding of referrals.
#referral	ldap://root.openldap.org

pidfile		/var/run/slapd.pid
argsfile	/var/run/slapd.args

# Load dynamic backend modules:
modulepath	/usr/lib/openldap
moduleload	back_mdb.so
# moduleload	back_hdb.la
# moduleload	back_ldap.la

# Certificate/SSL Section
TLSCipherSuite DEFAULT
TLSCertificateFile ${CERT_DIR}/${LDAP_HOST}_host.pem
TLSCertificateKeyFile ${PRIV_KEY_DIR}/${LDAP_HOST}_host.key

# Sample security restrictions
#	Require integrity protection (prevent hijacking)
#	Require 112-bit (3DES or better) encryption for updates
#	Require 63-bit encryption for simple bind
#security ssf=1 update_ssf=112 simple_bind=64


# Allow reading server config, base dn etc
access to dn.base=""
	by users read
	by * none

access to dn.base="cn=Subschema"
	by users read
	by * none

access to dn.base="cn=config"
	by users read
	by * none

# Allow binding as SysAdmin only from localhost
access to dn.base="CN=SysAdmin,${BASE_DN}"
	by peername.regex=127\.0\.0\.1 auth
	by * none

# Allow admins to change passwords, and prevent
# users from reading each other's password hashes
# Also allow only users/host on the local network/domain to authenticate
access to attrs="userPassword"
	by set="[CN=admins,OU=User Groups,${BASE_DN}]/memberUid & user/uid" write
	by self write
	by peername.regex=${SUBNET_REGEXP} auth
	by peername.regex=${HOSTNAME_REGEXP} auth
	by * none

# Allow only authenticated users to read real names/mobile phones/mail addresses
# numbers. Allow admins to modify them and users to modify their own.
access to attrs="gecos,mobile,mail"
	by set="[CN=admins,OU=User Groups,${BASE_DN}]/memberUid & user/uid" write
	by self write
	by users read
	by * none

# Allow admins to create users and users (including hosts) to authenticate and read user data.
access to dn.subtree="ou=Users,${BASE_DN}"
	by set="[CN=admins,OU=User Groups,${BASE_DN}]/memberUid & user/uid" write
	by self write
	by users read
	by * none

# Allow admins to add users to user groups and users (including hosts) to read them
access to dn.subtree="ou=User Groups,${BASE_DN}"
	by set="[CN=admins,OU=User Groups,${BASE_DN}]/memberUid & user/uid" write
	by users read
	by * none

# Allow admins to add hosts and users (including hosts) to read them
access to dn.subtree="ou=Hosts,${BASE_DN}"
	by set="[CN=admins,OU=User Groups,${BASE_DN}]/memberUid & user/uid" write
	by users read
	by * none

#
# if no access controls are present, the default policy
# allows anyone and everyone to read anything but restricts
# updates to rootdn.  (e.g., "access to * by * read")
#
# rootdn can always read and write EVERYTHING!

#######################################################################
# MDB database definitions
#######################################################################

database	mdb
maxsize		1073741824
suffix		"${BASE_DN}"
rootdn		"CN=SysAdmin,${BASE_DN}"

# Cleartext passwords, especially for the rootdn, should
# be avoid.  See slappasswd(8) and slapd.conf(5) for details.
# Use of strong authentication encouraged.
rootpw		"${LDAP_BIND_PASS}"

# The database directory MUST exist prior to running slapd AND 
# should only be accessible by the slapd and slap tools.
# Mode 700 recommended.
directory	${LDAP_DATA_DIR}

# Indices to maintain
index	objectClass	eq

EOF
