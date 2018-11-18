################
# ROOT DN INFO #
################

# Note that all of the DN fields below should be filled
ROOT_C="GR"
ROOT_ST="Crete"
ROOT_L="Heraklion"
ROOT_O="University of Crete"
ROOT_OU="Radio Station"
ROOT_DESC="UoC Radio 96.7"
ROOT_PHONE="<changeme>"
ROOT_REG_ADDR="<changeme>"
ROOT_POSTAL_CODE="<changeme>"
ROOT_CA_CN="CA"
ROOT_MAIL="<changeme>"

# Used by LDAP scripts, don't modify
BASE_DN="OU=${ROOT_OU},O=${ROOT_O},L=${ROOT_L},ST=${ROOT_ST},C=${ROOT_C}"

ROOT_DOMAIN="<changeme>"

# Used to upload ca certificate,
# user bundles and distribute the CRL
CA_HOST="<changeme>"

# A user we can ssh to using certificate
# based auth (no password) for uploading.
#
# Files will be put on <user's home>/ca/
# make sure this folder is accessible via
# web under http://CA_HOST/ca/ so that
# CRL distribution works as expected.
CA_HOST_USER="<changeme>"

######################
# LDAP CONFIGURATION #
######################

# We use the following on OpenWRT
LDAP_CONF_DIR=/etc/openldap
LDAP_DATA_DIR=/srv/openldap-data
LDAP_HOSTS_CONF_DIR=/root/ldap-confs
LOCAL_SUBNET="<changeme>"

# The first one is for generating the certificate
# the other is used for hosts to reach the LDAP since
# dns might not be available (e.g. if it's through LDAP).
LDAP_HOST="<changeme>"
LDAP_HOST_IP="<changeme>"

# UID below which users from LDAP will be ignored
# This is used so that LDAP users don't overlap with
# local users. Make sure GLOBAL_USERS below have UIDs
# below that number.
LDAP_MIN_UID="<changeme>"

# The DN to bind to when performing
# admin tasks
BIND_DN="cn=SysAdmin,${BASE_DN}"

# If user hasn't supplied a public key / CSR,
# this password is used for local logins, until
# the user logs in localy for the first time -he/she
# then is forced to change it-.
DEFAULT_USER_PASS="<changeme>"
LDAP_BIND_PASS="<changeme>"

####################
# CA CONFIGURATION #
###################

#
# Directories
#

CERT_DIR=/srv/ca/certs
PRIV_KEY_DIR=/srv/ca/keys
CRL_DIR=/srv/ca/crl
CSR_DIR=/srv/ca/csr
BUNDLE_DIR=/srv/ca/bundles

#
# Crypto parameters
#

# Available types: rsa / ec
GENKEY_TYPE=ec

# For rsa only
GENKEY_LEN=2048

# For ecc
# Note: not all openssl curves are recognizable
# by ssh, an unknown curve will result ssh-unknown
# on ssh-keygen.
ECC_CURVE=secp256r1
ECPARAMS_FILE=${PRIV_KEY_DIR}/ecparams

# Check openssl's supported list
SIGN_MD=sha256

CA_DAYS="3650"
CERT_DAYS="365"

# For SSH CA key
SSH_CA_KEY_TYPE=ed25519

# OpenSSL temporary config file
OSSL_CNF=/tmp/ossl.cnf

# CRL distribution point
CRL_DIST_POINT="http://${CA_HOST}/ca/crl.pem"

# Extra principals to put on SSH certificates
# (e.g. user accounts not managed by ldap)
# These will also be ignored by nss_ldap.
GLOBAL_USERS=",studiouser,libraryuser"

SCDIR=${SCRIPT_PATH}
