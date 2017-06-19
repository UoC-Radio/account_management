#!/bin/bash

# This script initializes the LDAP and CA setup
# Make sure to edit common/config.sh before running it.

SCRIPT=$(readlink -f $0)
SCRIPT_PATH=`dirname $SCRIPT`
source ${SCRIPT_PATH}/common/config.sh
source ${SCRIPT_PATH}/ca_management/ca_functions.sh
source ${SCRIPT_PATH}/ldap_management/ldap_functions.sh

log () {
        echo ${1}
}

# We don't have slappaswd on openwrt
# so grab the hash from the ldif file
# directly (it's ugly, I know).
get_sysadmin_hashed_pass () {
        local TMP=$(echo ${BASE_DN}/cn=sysadmin.ldif | awk '{print tolower($0)}')
        local SYSADMIN_LDIF="${LDAP_DATA_DIR}/${TMP}"
        local PASS_ENC=$(cat "${SYSADMIN_LDIF}" | grep userPassword | awk '{print $2}')
        SYSADMIN_PHASH=$(echo ${PASS_ENC} | base64 -d -)
}

upload_ca_certs () {
	scp ${CERT_DIR}/ca.pem dbsync@${CA_HOST}:~/ca/
	scp ${CERT_DIR}/ssh_ca.pub dbsync@${CA_HOST}:~/ca/
	log "Upladed CA certificates to web"
}

upload_crls () {
	log "Generating CRLs"
	ca_gen_crl
	ssh_ca_gen_crl
	scp ${CRL_DIR}/crl.pem dbsync@${CA_HOST}:~/ca/
	scp ${CRL_DIR}/ssh_crl dbsync@${CA_HOST}:~/ca/
	log "Upladed renewed CRLs to web"
}

# Create CA
#${SCRIPT_PATH}/ca_management/ca_init.sh

# Using CA, build LDAP's certificate
#${SCRIPT_PATH}/ca_management/gen_host_cert.sh ${LDAP_HOST}

# Generate LDAP's config file and put the custom
# schema on the schema subdirectory.
${SCRIPT_PATH}/ldap_management/generate_slapd.conf.sh
cp ${SCRIPT_PATH}/ldap_management/custom-schema/* ${LDAP_CONF_DIR}/schema/

# Create LDAP's data directory
mkdir -p ${LDAP_DATA_DIR}

# Reload config in case slapd is running
# else run it.
pidof slapd &> /dev/null
if [[ $? != 0 ]]; then
	slapd -h "ldap://localhost/ ldaps:///"
else
	# Didn't work on openwrt
	# killall -s SIGHUP slapd
	killall slapd
	slapd -h "ldap://localhost/ ldaps:///"
fi

# Initialize LDAP structure
${SCRIPT_PATH}/ldap_management/ldap_init.sh

# Add LDAP host on LDAP
${SCRIPT_PATH}/ldap_management/add_ldap_host.sh ${LDAP_HOST} ${LDAP_HOST_IP}

# Get its ldap.conf and put it on the config dir, overwrite
# any existing one
mv ${LDAP_HOSTS_CONF_DIR}/${LDAP_HOST}/ldap.conf ${LDAP_CONF_DIR}/ldap.conf

# Remove plaintext rootpw from slapd.conf
cat ${LDAP_CONF_DIR}/slapd.conf | grep -v "rootpw" > /tmp/tmp.conf
cat /tmp/tmp.conf > ${LDAP_CONF_DIR}/slapd.conf
rm /tmp/tmp.conf

# Now grab the password hash from the directory and
# put rootpw back on slapd.conf
get_sysadmin_hashed_pass
echo "rootpw	\"${SYSADMIN_PHASH}\"" >> ${LDAP_CONF_DIR}/slapd.conf

#upload_ca_certs
#upload_crls
