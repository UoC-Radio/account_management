#!/bin/bash

SCRIPT=$(readlink -f $0)
SCRIPT_PATH=`dirname $SCRIPT`
source ${SCRIPT_PATH}/ca_functions.sh
source ${SCRIPT_PATH}/config.sh

# Input: ${1} -> username

ca_gen_user_cert ${1}
ssh_ca_gen_user_cert ${1}
