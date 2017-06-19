DN_C=""
DN_ST=""
DN_L=""
DN_O=""
DN_OU=""
DN_CN=""

SAN_DNS=""
SAN_IP=""
SAN_MAIL=""

SERIAL=""


##################################
# OPENSSL CONFIG FILE GENERATION #
##################################

#
# Temporary OpenSSL configuration file
# generation. The generated config file
# is per-command. They all use variables
# from the config.sh file.
#

# Set the DN on the generated
# Certificate Signing Request (CSR)
ca_set_csr_dn () {
	echo "[req_distinguished_name]
	C  = \"${DN_C}\"
	ST = \"${DN_ST}\"
	L  = \"${DN_L}\"
	O  = \"${DN_O}\"
	OU = \"${DN_OU}\"
	CN = \"${DN_CN}\"" >> ${OSSL_CNF}

	echo "[req]
	distinguished_name = req_distinguished_name
	prompt = no
	encrypt_key = no" >> ${OSSL_CNF}
}

# Set a DNS Sublect Alternative Name
# (SAN) extention on the generated certificate
ca_set_csr_sans () {
	echo "[ req_alt ]
	DNS.1 = \"${SAN_DNS}\"" >> ${OSSL_CNF}
}

# Set the Certificate Authority (CA) configuration
ca_set_ca_conf () {
	echo "[ policy_match ]
	countryName		= match
	stateOrProvinceName	= match
	localityName		= match
	organizationName	= match
	organizationalUnitName	= supplied
	commonName		= supplied
	emailAddress		= optional" >> ${OSSL_CNF}

	echo "[ CA_default ]
	certs		= ${CERT_DIR}
	new_certs_dir	= ${CERT_DIR}/new
	crldir		= ${CRL_DIR}
	database	= ${CRL_DIR}/index
	serial		= ${CRL_DIR}/serial
	crlnumber	= ${CRL_DIR}/crlnumber
	crl		= ${CRL_DIR}/crl.pem
	default_crl_days = 1
	certificate	= ${CERT_DIR}/ca.pem
	private_key	= ${PRIV_KEY_DIR}/ca.key
	default_days	= ${CERT_DAYS}
	preserve	= no
	default_md	= ${SIGN_MD}
	x509_extensions	= v3_exts
	copy_extensions	= none
	policy		= policy_match
	unique_subject	= yes" >> ${OSSL_CNF}

	echo "[ ca ]
	default_ca = CA_default" >> ${OSSL_CNF}
}

# Sets extensions for a CA self-signed certificate
ca_set_csr_ca_extensions () {
	echo "[ v3_exts ]
	basicConstraints	= critical, CA:TRUE
	subjectKeyIdentifier	= hash
	authorityKeyIdentifier	= keyid:always, issuer:always
	crlDistributionPoints	= URI:${CRL_DIST_POINT}
	keyUsage		= critical, cRLSign, digitalSignature, \
				  keyCertSign
	issuerAltName	= DNS:${ROOT_DOMAIN}" >> ${OSSL_CNF}
}

# Sets extensions for a server-side certificate
ca_set_csr_srv_extensions () {
	echo "[ v3_exts ]
	basicConstraints	= critical, CA:FALSE
	subjectKeyIdentifier	= hash
	authorityKeyIdentifier	= keyid:always, issuer:always
	crlDistributionPoints	= URI:${CRL_DIST_POINT}
	keyUsage		= critical, nonRepudiation, digitalSignature, \
				  keyEncipherment, keyAgreement
	extendedKeyUsage	= critical, serverAuth
	subjectAltName		= @req_alt
	issuerAltName		= DNS:${ROOT_DOMAIN}" >> ${OSSL_CNF}
}

# Sets extensions for a client-side (user) certififate
ca_set_csr_user_extensions () {
	echo "[ v3_exts ]
	basicConstraints	= critical, CA:FALSE
	subjectKeyIdentifier	= hash
	authorityKeyIdentifier	= keyid:always, issuer:always
	crlDistributionPoints	= URI:${CRL_DIST_POINT}
	keyUsage		= critical, nonRepudiation, digitalSignature, \
				  keyEncipherment
	extendedKeyUsage	= critical, clientAuth, emailProtection
	issuerAltName		= DNS:${ROOT_DOMAIN}" >> ${OSSL_CNF}
}


#######################
# CA HELPER FUNCTIONS #
#######################

# Sets the KEYSPEC variable, used for CSR / Self-signed cert key generation
ca_set_keyspec () {
	KEYSPEC=""

	if [[ ${GENKEY_TYPE} == "rsa" ]] ; then
		KEYSPEC="rsa:${GENKEY_LEN}"		
	elif [[ ${GENKEY_TYPE} == "ec" ]] ; then
		if [[ ! -f ${ECPARAMS_FILE} ]] ; then
			openssl ecparam -name ${ECC_CURVE} -out ${ECPARAMS_FILE}
		fi
		KEYSPEC="ec:${ECPARAMS_FILE}"
	else
		echo "Invalid key parameters"
		exit -1;
	fi
}

# Maps a username to its certificate's serial number, using the
# CA database (index) file
# Arguments: username
ca_get_user_serial () {
	STATUS=`cat ${CRL_DIR}/index | grep "\<OU=Users/CN=${1}\>" | \
		awk '{print$1}'`

	SERIAL=""
	if [[ ${STATUS} == "R" ]]; then
		SERIAL=`cat ${CRL_DIR}/index | grep "\<OU=Users/CN=${1}\>" | \
			awk '{print$4}'`
	else
		SERIAL=`cat ${CRL_DIR}/index | grep "\<OU=Users/CN=${1}\>" | \
			awk '{print$3}'`
	fi
}

# Maps a hostname to its certificate's serial number, using the
# CA database (index) file
# Arguments: hostname
ca_get_host_serial () {
	STATUS=`cat ${CRL_DIR}/index | grep "\<OU=Hosts/CN=${1}\>" | \
		awk '{print$1}'`

	SERIAL=""
	if [[ ${STATUS} == "R" ]]; then
		SERIAL=`cat ${CRL_DIR}/index | grep "\<OU=Hosts/CN=${1}\>" | \
			awk '{print$4}'`
	else
		SERIAL=`cat ${CRL_DIR}/index | grep "\<OU=Hosts/CN=${1}\>" | \
			awk '{print$3}'`
	fi
}


#
# CSR generation
# Used for local testing
#

# Generate a CSR to be signed later
# Arguments: Name of the csr file / key file
# Note: DN and extensions / SANs should be set before on
#	OSSL_CNF
ca_gen_csr () {
	ca_set_keyspec

	openssl req -new -${SIGN_MD} -days ${CERT_DAYS} \
		-newkey ${KEYSPEC} \
		-keyout "${PRIV_KEY_DIR}/${1}.key" \
		-out "${CSR_DIR}/${1}.pem" \
		-config ${OSSL_CNF} -extensions v3_exts
}

# Generates a CSR for the given host
# Arguments: Hostname (without the domain part)
ca_gen_host_csr () {
	echo "" > ${OSSL_CNF}

	DN_C="${ROOT_C}"
	DN_ST="${ROOT_ST}"
	DN_L="${ROOT_L}"
	DN_O="${ROOT_O}"
	DN_OU="${ROOT_OU}/OU=Hosts"
	DN_CN="${1}"

	SAN_DNS="${1}.${ROOT_DOMAIN}"

	ca_set_csr_dn
	ca_set_csr_sans
	ca_set_csr_srv_extensions
	ca_gen_csr ${1}_host
}

# Generates a CSR for the given user
# Arguments: username
ca_gen_user_csr () {
	echo "" > ${OSSL_CNF}

	DN_C="${ROOT_C}"
	DN_ST="${ROOT_ST}"
	DN_L="${ROOT_L}"
	DN_O="${ROOT_O}"
	DN_OU="${ROOT_OU}/OU=Users"
	DN_CN="${1}"

	ca_set_csr_dn
	ca_set_csr_user_extensions
	ca_gen_csr ${1}
}


#
# Certificate generation
# This includes CSR generation + signing from the CA
# Used for local testing
#

# Sign a CSR file
# Arguments: CSR filename inside CSR_DIR
# Note: Extensions need to be set before since they are
#	not copied from the generated CSR
ca_sign_csr () {
	ca_set_ca_conf

	openssl ca \
		-config ${OSSL_CNF} \
		-in "${CSR_DIR}/${1}.pem" \
		-notext \
		-batch &> /dev/null

	rm "${CSR_DIR}/${1}.pem"
	rm ${OSSL_CNF}
}

# Generate a host certificate
# Arguments: hostname
ca_gen_host_cert () {
	ca_gen_host_csr ${1}
	ca_sign_csr ${1}_host

	ca_get_host_serial "${1}"
	ln -s ${CERT_DIR}/new/${SERIAL}.pem ${CERT_DIR}/${1}_host.pem
}

# Generate a user certificate
# Arguments: username
ca_gen_user_cert () {
	ca_gen_user_csr ${1}
	ca_sign_csr ${1}

	ca_get_user_serial "${1}"
	ln -s ${CERT_DIR}/new/${SERIAL}.pem ${CERT_DIR}/${1}.pem
}


#################
# CA OPERATIONS #
#################

# Generate a self-signed certificate
# Arguments: Name of the certificate file / key file
# Note: DN and extensions / SANs should be set before on OSSL_CNF
#	this is used for generating the root CA certificate / key
ca_gen_self_signed () {
	ca_set_keyspec

	openssl req -x509 -new -${SIGN_MD} -days ${CA_DAYS} \
		-newkey ${KEYSPEC} \
		-keyout "${PRIV_KEY_DIR}/${1}.key" \
		-out "${CERT_DIR}/${1}.pem" \
		-config "${OSSL_CNF}" -extensions v3_exts -batch
}

# Note: When signing CSRs we didn't generate, we ignore the DN
# passed from the user since we don't trust user input, for example
# a user might ask us to sign a certificate for another username.
# Instead of further filtering the DN -we already filter it on CA's
# policy definition- we just ignore it and override it with the one
# we generate. We also don't copy any extensions from the CSRs -see
# CA's policy config above. The only thing we want to use is the
# user's/host's public key. Unfortunately the openssl command line
# tool doesn't support generation of unsigned CSRs -if it did
# we'd create the CSR form the user's public key ourselves, now
# it needs the private key as well in order to sign it-.

# Sign a user CSR
# Arguments: username
# Note: The CSR file is expected to be on CSR_DIR/<username>.pem
#	Signed certificate goes to CERT_DIR/<username>.pem
ca_sign_user_csr () {
	echo "" > ${OSSL_CNF}

	# Override DN
	CUR_DN="/C=${ROOT_C}/ST=${ROOT_ST}/L=${ROOT_L}/O=${ROOT_O}/OU=${ROOT_OU}/OU=Users/CN=${1}"

	ca_set_csr_user_extensions
	ca_set_ca_conf

	openssl ca \
		-config ${OSSL_CNF} \
		-in "${CSR_DIR}/${1}.pem" \
		-subj "${CUR_DN}" \
		-notext \
		-batch &> /dev/null

	# Generated certificate is stored in CERT_DIR/new/<serial number>.pem
	# link it to CERT_DIR/<username>.pem
	ca_get_user_serial "${1}"

	ln -s ${CERT_DIR}/new/${SERIAL}.pem ${CERT_DIR}/${1}.pem

	rm "${CSR_DIR}/${1}.pem"
	rm ${OSSL_CNF}
}

# Sign a host/server CSR
# Arguments: hostname
# Note: The CSR file is expected to be on CSR_DIR/<hostname>_host.pem
#	Signed certificate goes to CERT_DIR/<hostname>_host.pem
ca_sign_host_csr () {
	echo "" > ${OSSL_CNF}

	# Override DN
	CUR_DN="/C=${ROOT_C}/ST=${ROOT_ST}/L=${ROOT_L}/O=${ROOT_O}/OU=${ROOT_OU}/OU=Hosts/CN=${1}"

	SAN_DNS="${1}.${ROOT_DOMAIN}"

	ca_set_csr_sans
	ca_set_csr_srv_extensions
	ca_set_ca_conf

	openssl ca \
		-config ${OSSL_CNF} \
		-in "${CSR_DIR}/${1}_host.pem" \
		-subj "${CUR_DN}" \
		-notext \
		-batch &> /dev/null

	# Generated certificate is stored in CERT_DIR/new/<serial number>.pem
	# link it to CERT_DIR/<hostname>_host.pem
	ca_get_host_serial "${1}"

	ln -s ${CERT_DIR}/new/${SERIAL}.pem ${CERT_DIR}/${1}_host.pem

	rm "${CSR_DIR}/${1}_host.pem"
	rm ${OSSL_CNF}
}

# Generate the CRL file based on the CA database (index) file
ca_gen_crl () {
	echo "" > ${OSSL_CNF}
	ca_set_ca_conf

	openssl ca -gencrl \
		-keyfile "${PRIV_KEY_DIR}/ca.key" \
		-cert "${CERT_DIR}/ca.pem" \
		-out "${CRL_DIR}/crl.pem" \
		-config ${OSSL_CNF}

	rm ${OSSL_CNF}
}

# Mark a user certificate as revoked on the CA database (index) file
# Arguments: username
# Note: Call ca_gen_crl afterwards to update the CRL
ca_revoke_user_cert () {
	echo "" > ${OSSL_CNF}
	ca_set_ca_conf

	ca_get_user_serial "${1}"

	openssl ca -config ${OSSL_CNF} \
		-revoke "${CERT_DIR}/new/${SERIAL}.pem"

	rm ${OSSL_CNF}
}

# Mark a user certificate as valid on the CA database (index) file
# Arguments: username
# Note: Call ca_gen_crl afterwards to update the CRL
ca_unrevoke_user_cert () {
	mv ${CRL_DIR}/index ${CRL_DIR}/index.old
	cat ${CRL_DIR}/index.old | grep -v "\OU=Users/CN=${1}\b" > ${CRL_DIR}/index
	cat ${CRL_DIR}/index.old | grep "\OU=Users/CN=${1}\b" | \
	awk -F"\t" 'BEGIN {OFS="\t"} {print "V",$2,"",$4,$5,$6}' >> ${CRL_DIR}/index
}

# Mark a host certificate as revoked on the CA database (index) file
# Arguments: hostname
# Note: Call ca_gen_crl afterwards to update the CRL
ca_revoke_host_cert () {
	echo "" > ${OSSL_CNF}
	ca_set_ca_conf

	ca_get_host_serial "${1}"

	openssl ca -config ${OSSL_CNF} \
		-revoke "${CERT_DIR}/new/${SERIAL}.pem"

	rm ${OSSL_CNF}
}

# Mark a host certificate as valid on the CA database (index) file
# Arguments: hostname
# Note: Call ca_gen_crl afterwards to update the CRL
ca_unrevoke_host_cert () {
	mv ${CRL_DIR}/index ${CRL_DIR}/index.old
	cat ${CRL_DIR}/index.old | grep -v "\OU=Hosts/CN=${1}\b" > ${CRL_DIR}/index
	cat ${CRL_DIR}/index.old | grep "\OU=Hosts/CN=${1}\b" | \
	awk -F"\t" 'BEGIN {OFS="\t"} {print "V",$2,"",$4,$5,$6}' >> ${CRL_DIR}/index
}

# Initialize CA directory structure / files and root certificate
ca_init () {
	echo "" > ${OSSL_CNF}

	# Create directory structure and base files
	mkdir -p ${CRL_DIR}
	echo 00 > ${CRL_DIR}/serial
	echo 00 > ${CRL_DIR}/crlnumber
	touch ${CRL_DIR}/index

	mkdir -p ${CSR_DIR}
	mkdir -p ${CERT_DIR}
	mkdir -p ${CERT_DIR}/new
	mkdir -p ${PRIV_KEY_DIR}
	mkdir -p ${BUNDLE_DIR}

	# Gemerate CA certificate
	DN_C=${ROOT_C}
	DN_ST=${ROOT_ST}
	DN_L=${ROOT_L}
	DN_O=${ROOT_O}
	DN_OU=${ROOT_OU}
	DN_CN=${ROOT_CA_CN}

	ca_set_csr_dn
	ca_set_csr_ca_extensions

	SAN_DNS=""
	SAN_IP=""
	SAN_MAIL=${ROOT_MAIL}

	ca_set_csr_sans
	ca_gen_self_signed ca

	# Generate CRL
	ca_gen_crl
}


#####################
# SSH CA OPERATIONS #
#####################

#
# SSH CA Certificate generation
# Note: These functions assume that an x509 certificate for
# the given host/user has already been generated.
#

# Generate an SSH user certificate from the existing x509 certificate
# Arguments: username
# Note: Existing certificate is expected at CERT_DIR/<username>.pem
ssh_ca_gen_user_cert () {
	# Dump public key in PKCS8 format from certificate
	openssl x509 -in "${CERT_DIR}/${1}.pem" -noout \
		     -pubkey > "/tmp/tmp-${1}.pkey"

	# Convert it to ssh (RFC4716) format
	ssh-keygen -f "/tmp/tmp-${1}.pkey" -i \
		   -m PKCS8 > "/tmp/tmp-${1}.pub"

	# Serial number on CA database file is in hex, ssh certificates
	# expect serial number in decimal, so convert it here
	ca_get_user_serial ${1}
	SERIAL=$((16#${SERIAL}))

	# Now create and sign the ssh certificate
	ssh-keygen -s ${PRIV_KEY_DIR}/ssh_ca -I id_${SERIAL} \
		   -n ${1}${GLOBAL_USERS} -z ${SERIAL} \
		   -V +${CERT_DAYS}d "/tmp/tmp-${1}.pub"

	rm "/tmp/tmp-${1}.pub"
	rm "/tmp/tmp-${1}.pkey"

	# While there, cleanup the trailing filename
	cat "/tmp/tmp-${1}-cert.pub" | sed 's/\/tmp\/tmp-//' >\
	    "${CERT_DIR}/${1}.pub"

	rm "/tmp/tmp-${1}-cert.pub"
}

# Generate an SSH host certificate from the existing x509 certificate
# Arguments: hostname
ssh_ca_gen_host_cert () {

	# Dump public key in PKCS8 format from certificate
	openssl x509 -in "${CERT_DIR}/${1}_host.pem" -noout \
		     -pubkey > "/tmp/tmp-${1}_host.pkey"

	# Convert it to ssh (RFC4716) format
	ssh-keygen -f "/tmp/tmp-${1}_host.pkey" -i \
		   -m PKCS8 > "/tmp/tmp-${1}_host.pub"

	# Serial number on CA database file is in hex, ssh certificates
	# expect serial number in decimal, so convert it here
	ca_get_host_serial ${1}
	SERIAL=$((16#${SERIAL}))

	# Now create and sign the ssh certificate
	ssh-keygen -s ${PRIV_KEY_DIR}/ssh_ca -I id_${SERIAL} -h \
		   -n ${1}.${ROOT_DOMAIN} -z ${SERIAL} \
		   -V +${CERT_DAYS}d "/tmp/tmp-${1}_host.pub"

	rm "/tmp/tmp-${1}_host.pub"
	rm "/tmp/tmp-${1}_host.pkey"
	mv "/tmp/tmp-${1}_host-cert.pub" "${CERT_DIR}/${1}_host.pub"
}

# Put a certificate on the SSH KRL file
ssh_ca_revoke_cert () {
	if [[ ! -f ${CRL_DIR}/ssh_crl ]] ; then
		ssh-keygen -k -s ${PRIV_KEY_DIR}/ssh_ca \
			   -f ${CRL_DIR}/ssh_crl "${CERT_DIR}/${1}.pub"
	else
		ssh-keygen -k -u -s ${PRIV_KEY_DIR}/ssh_ca \
			   -f ${CRL_DIR}/ssh_crl "${CERT_DIR}/${1}.pub"
	fi
}

# Generate an SSH KRL file based on the CA database (index) file
ssh_ca_gen_crl () {
	local IFS=$'\n'

	local REVOKED_USER_CERTS=`cat ${CRL_DIR}/index | grep "\<R\>" | \
				  awk -F"OU=Users/CN=" '{print $2}'`

	local REVOKED_HOST_CERTS=`cat ${CRL_DIR}/index | grep "\<R\>" | \
				  awk -F"OU=Hosts/CN=" '{print $2}'`

	rm ${CRL_DIR}/ssh_crl
	ssh-keygen -k -s ${PRIV_KEY_DIR}/ssh_ca -f ${CRL_DIR}/ssh_crl

	for i in ${REVOKED_USER_CERTS}; do
		ssh_ca_revoke_cert ${i}
	done

	for i in ${REVOKED_HOST_CERTS}; do
		ssh_ca_revoke_cert ${i}_host
	done
}

# Generate the SSH CA certificate
ssh_ca_init () {
	ssh-keygen -t ${SSH_CA_KEY_TYPE} -f ${PRIV_KEY_DIR}/ssh_ca -P "" -q
	ln -s ${PRIV_KEY_DIR}/ssh_ca.pub ${CERT_DIR}/ssh_ca.pub
}
