#!/bin/bash

SCRIPT=$(readlink -f $0)
SCRIPT_PATH=`dirname $SCRIPT`
source ${SCRIPT_PATH}/common/config.sh
source ${SCRIPT_PATH}/ldap_management/ldap_functions.sh
source ${SCRIPT_PATH}/ca_management/ca_functions.sh

USER_ID=""
USERNAME=""
USER_TYPE=""
USER_EMAIL=""
USER_REAL_NAME=""
USER_MOBILE=""
USER_CSR=""

log () {
	echo ${1}
}

do_query () {
	ssh ${CA_HOST_USER}@${CA_HOST} /home/${CA_HOST_USER}/ulistquery
}

upload_bundle () {
	local TMP=`echo ${CERT_DIR} | sed 's/^\/\(.*\)/\1/'`
	tar chJf ${BUNDLE_DIR}/${USERNAME}.tar.xz --owner=${USERNAME} \
	    --group=users --no-xattrs --xform="s|${TMP}|certs-${USERNAME}|" \
	    ${CERT_DIR}/${USERNAME}.p*

	scp ${BUNDLE_DIR}/${USERNAME}.tar.xz ${CA_HOST_USER}@${CA_HOST}:~/ca/bundles/
}

empty_user () {
	USER_ID=""
	USERNAME=""
	USER_TYPE=""
	USER_EMAIL=""
	USER_REAL_NAME=""
	USER_MOBILE=""
	USER_CSR=""
}

process_user () {
	# NOTE: Forum user types 0 -> NORMAL, 1-> INACTIVE, 2-> IGNORE, 3-> FOUNDER
	# Should we ignore the user ?
	if [[ ${USER_TYPE} = 2 ]] ; then
		ldap_clear_last_user_info
		return;
	fi
	# Convert real name to ascii
	local ASCII_REAL_NAME=`echo ${USER_REAL_NAME} | \
			       iconv -f utf-8 -t ascii//translit 2> /dev/null`
	# Check if user exists
	ldap_lookup_user ${USERNAME}
	if [[ $? != 0 ]] ; then
		# If not create user
		local LDAP_UID=`expr 967000 + ${USER_ID}`
		log "Creating new user: ${USERNAME} (${LDAP_UID})"
		ldap_add_user "${USERNAME}" ${LDAP_UID} ${DEFAULT_USER_PASS}
		ldap_set_user_email "${USERNAME}" "${USER_EMAIL}"
		ldap_set_user_gecos "${USERNAME}" "${USER_REAL_NAME}"
		ldap_set_user_mobile "${USERNAME}" "${USER_MOBILE}"
	fi
	# User exists, get data from LDAP and update if needed
	ldap_get_user_info ${USERNAME}
	if [[ ${USER_TYPE} = 1 ]] ; then
		# User inactive
		if [[ ${LDAP_USER_EXPIRED} != 1 ]] ; then
			# Mark user's account as expired
			log "Marking ${USERNAME} as expired"
			ldap_disable_shadowaccount ${USERNAME}
		else
			# Already marked, no need to bother with the rest
			ldap_clear_last_user_info
			return;
		fi
	else
		if [[ ${LDAP_USER_EXPIRED} = 1 ]] ; then
			# re-enable user
			log "Re-enabling ${USERNAME}"
			ldap_enable_shadowaccount ${USERNAME}
		fi
	fi
	if [[ ${LDAP_USER_MAIL} != ${USER_EMAIL} ]] ; then
		log "Changing mail of ${USERNAME}"
		ldap_set_user_email "${USERNAME}" "${USER_EMAIL}"
	fi
	if [[ ${LDAP_USER_GECOS} != ${ASCII_REAL_NAME} ]] ; then
		log "Changing gecos of ${USERNAME}"
		ldap_set_user_gecos "${USERNAME}" "${ASCII_REAL_NAME}"
	fi
	if [[ ${LDAP_USER_MOBILE} != ${USER_MOBILE} ]] ; then
		log "Changing mobile of ${USERNAME}"
		ldap_set_user_mobile "${USERNAME}" "${USER_MOBILE}"
	fi
	if [[ ${USER_CSR} = *[^[:space:]]* ]] ; then
		# Check if user already has a certificate
		if [[ -f ${CERT_DIR}/${USERNAME}.pem ]] ; then
			return;
		fi

		# Generate a bundle for the user
		log "Got CSR from user ${USERNAME}"

		# First put the CSR in CSR_DIR/<username>.pem
		echo "${USER_CSR}" > "${CSR_DIR}/${USERNAME}.pem"
		ca_sign_user_csr ${USERNAME}

		# Check if the certificate was created as expected
		if [[ ! -f ${CERT_DIR}/${USERNAME}.pem ]] ; then
			log "User's CSR could not be signed, cleaning up..."
			rm ${CSR_DIR}/$USERNAME.pem
			return;
		fi

		log "User's certificate created"

		# Now generate teh SSH certificate
		ssh_ca_gen_user_cert ${USERNAME}

		# Check if it was created as expected
		if [[ ! -f ${CERT_DIR}/${USERNAME}.pub ]] ; then
			log "Could not create SSH certificate, cleaning up..."
			rm ${CERT_DIR}/${USERNAME}.pem
			rm ${CSR_DIR}/${USERNAME}.pem
		fi

		log "User's SSH certificate created"
		log "Uploading bundle file for ${USERNAME}"
		# All good, create/upload the bundle file
		upload_bundle
	fi

	ldap_clear_last_user_info
#	ldap_delete_user ${USERNAME}
}

read_dom () {
	local IFS=\>
	read -d \< ENTITY CONTENT
	local ret=$?
	TAG_NAME=${ENTITY%% *}
	ATTRIBUTES=${ENTITY#* }
	return $ret
}

parse_dom () {
	# New user row, empty user info
	if [[ $TAG_NAME = "row" ]] ; then
		empty_user;
	# Row is over, process user info
	elif [[ $TAG_NAME = "/row" ]] ; then
		process_user;
	# Fill user info
	elif [[ $TAG_NAME = "field" ]] ; then
		eval local $ATTRIBUTES &> /dev/null
		if [[ $name = "user_id" ]] ; then
			USER_ID=${CONTENT}
		elif [[ $name = "username" ]] ; then
			USERNAME=`echo ${CONTENT} | awk '{print tolower($0)}'`
		elif [[ $name = "user_type" ]] ; then
			USER_TYPE=${CONTENT}
		elif [[ $name = "user_email" ]] ; then
			USER_EMAIL=${CONTENT}
		elif [[ $name = "pf_real_life_name" ]] ; then
			USER_REAL_NAME=${CONTENT}
		elif [[ $name = "pf_mobile_phone" ]] ; then
			USER_MOBILE=${CONTENT}
		elif [[ $name = "pf_csr" ]] ; then
			USER_CSR=${CONTENT}
		fi
	fi
}

process () {
	while read_dom; do
		parse_dom
	done
}

ldap_set_bind_password ${LDAP_BIND_PASS}
do_query | process
