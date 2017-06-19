#!/bin/bash

SCRIPT=$(readlink -f $0)
SCRIPT_PATH=`dirname $SCRIPT`
source ${SCRIPT_PATH}/ca_functions.sh
source ${SCRIPT_PATH}/config.sh

# Input: ${1} -> uername

ca_revoke_user_cert ${1}
ca_gen_crl
ssh_ca_gen_crl
