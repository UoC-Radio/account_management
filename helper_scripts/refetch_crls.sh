#!/bin/bash

SCRIPT=$(readlink -f $0)
SCRIPT_PATH=`dirname $SCRIPT`

# Input ${1} -> CA_HOST, same as the one in config.sh

# Grab SSH CRL from webserver (this should go on a cron-job
# to always have an up to date CRL)
wget http://${CA_HOST}/ca/ssh_crl -O /etc/ssh/ssh_crl
