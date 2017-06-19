#!/bin/bash

local SCRIPT=$(readlink -f $0)
local SCRIPT_PATH=`dirname $SCRIPT`
source ${SCRIPT_PATH}/common/config.sh
source ${SCRIPT_PATH}/ca_management/ca_functions.sh

log () {
        echo ${1}
}

update_crls () {
	log "Re-generating CRLs"
	ca_gen_crl
	ssh_ca_gen_crl
	scp ${CRL_DIR}/crl.pem dbsync@${CA_HOST}:~/ca/
	scp ${CRL_DIR}/ssh_crl dbsync@${CA_HOST}:~/ca/
	log "Upladed renewed CRLs to web"
}

update_crls
