#!/bin/bash

SCRIPT=$(readlink -f $0)
SCRIPT_PATH=`dirname $SCRIPT`
source ${SCRIPT_PATH}/ca_functions.sh
source ${SCRIPT_PATH}/config.sh

# Input: ${1} -> hostname

ca_gen_host_csr ${1}
