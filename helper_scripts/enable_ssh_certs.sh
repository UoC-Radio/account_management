#!/bin/bash

SCRIPT=$(readlink -f $0)
SCRIPT_PATH=`dirname $SCRIPT`

# Input: ${1} -> CA_HOST, same as the one in config.sh

# Grab SSH CA cert from webserver
wget http://${1}/ca/ssh_ca.pub -O /etc/ssh/ssh_ca.pub

# Grab SSH CRL from webserver (this should go on a cron-job
# to always have an up to date CRL)
wget http://${1}/ca/ssh_crl -O /etc/ssh/ssh_crl

# Modify sshd_config
echo "TrustedUserCAKeys /etc/ssh/ssh_ca.pub" >> /etc/ssh/sshd_config
echo "RevokedKeys /etc/ssh/ssh_crl" >> /etc/ssh/sshd_config
