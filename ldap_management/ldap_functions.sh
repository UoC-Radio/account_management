#################
# INITIAL SETUP #
#################

ldap_setup_init () {
	# Create directory for generated host config files
	mkdir -p ${LDAP_HOSTS_CONF_DIR}

	# Add top organizational unit
	echo "version: 1" > /tmp/tmp.ldif
	echo "dn: ${BASE_DN}" >> /tmp/tmp.ldif
	echo "objectClass: top" >> /tmp/tmp.ldif
	echo "objectClass: organizationalUnit" >> /tmp/tmp.ldif
	echo "ou: ${ROOT_OU}" >> /tmp/tmp.ldif
	echo "description: ${ROOT_DESC}" >> /tmp/tmp.ldif
	echo "telephoneNumber: ${ROOT_PHONE}" >> /tmp/tmp.ldif
	echo "registeredAddress: ${ROOT_REG_ADDR}" >> /tmp/tmp.ldif
	echo "postalCode: ${ROOT_POSTAL_CODE}" >> /tmp/tmp.ldif

	ldapadd -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/tmp.ldif

	# Add SysAdmin and set its bind
	# password on LDAP as well
	DN="cn=SysAdmin,${BASE_DN}"
	echo "version: 1" > /tmp/tmp.ldif
	echo "dn: ${DN}" >> /tmp/tmp.ldif
	echo "objectClass: organizationalRole" >> /tmp/tmp.ldif
	echo "objectClass: simpleSecurityObject" >> /tmp/tmp.ldif
	echo "userPassword: ${LDAP_BIND_PASS}" >> /tmp/tmp.ldif
	echo "cn: Manager" >> /tmp/tmp.ldif
	echo "description: Directory Manager" >> /tmp/tmp.ldif

	ldapadd -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/tmp.ldif

	# Re-set password through ldappasswd so that it's not stored
	# in plaintext.
	ldappasswd -s ${LDAP_BIND_PASS} -w "${BIND_PASSWORD}" -D "${BIND_DN}" -x "${DN}"

	# Add root for users
	DN="ou=Users,${BASE_DN}"
	echo "version: 1" > /tmp/tmp.ldif
	echo "dn: ${DN}" >> /tmp/tmp.ldif
	echo "objectClass: organizationalUnit" >> /tmp/tmp.ldif
	echo "ou: Users" >> /tmp/tmp.ldif
	echo "description: Root node for users" >> /tmp/tmp.ldif

	ldapadd -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/tmp.ldif

	# Add root for user groups
	DN="ou=User Groups,${BASE_DN}"
	echo "version: 1" > /tmp/tmp.ldif
	echo "dn: ${DN}" >> /tmp/tmp.ldif
	echo "objectClass: organizationalUnit" >> /tmp/tmp.ldif
	echo "ou: User Groups" >> /tmp/tmp.ldif
	echo "description: Root node for user groups" >> /tmp/tmp.ldif

	ldapadd -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/tmp.ldif

	# Add "users" user group
	DN="cn=users,ou=User Groups,${BASE_DN}"
	echo "version: 1" > /tmp/tmp.ldif
	echo "dn: ${DN}" >> /tmp/tmp.ldif
	echo "objectClass: posixGroup" >> /tmp/tmp.ldif
	echo "cn: users" >> /tmp/tmp.ldif
	echo "gidNumber: 100" >> /tmp/tmp.ldif
	echo "description: Normal users" >> /tmp/tmp.ldif

	ldapadd -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/tmp.ldif

	# Add "admins" user group
	DN="cn=admins,ou=User Groups,${BASE_DN}"
	echo "version: 1" > /tmp/tmp.ldif
	echo "dn: ${DN}" >> /tmp/tmp.ldif
	echo "objectClass: posixGroup" >> /tmp/tmp.ldif
	echo "cn: admins" >> /tmp/tmp.ldif
	echo "gidNumber: 967000" >> /tmp/tmp.ldif
	echo "description: Administrators" >> /tmp/tmp.ldif

	ldapadd -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/tmp.ldif

	# Add "library" user group
	DN="cn=library,ou=User Groups,${BASE_DN}"
	echo "version: 1" > /tmp/tmp.ldif
	echo "dn: ${DN}" >> /tmp/tmp.ldif
	echo "objectClass: posixGroup" >> /tmp/tmp.ldif
	echo "cn: library" >> /tmp/tmp.ldif
	echo "gidNumber: 967967" >> /tmp/tmp.ldif
	echo "description: Library Group" >> /tmp/tmp.ldif

	ldapadd -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/tmp.ldif

	# Add root for hosts
	DN="ou=Hosts,${BASE_DN}"
	echo "version: 1" > /tmp/tmp.ldif
	echo "dn: ${DN}" >> /tmp/tmp.ldif
	echo "objectClass: organizationalUnit" >> /tmp/tmp.ldif
	echo "ou: Hosts" >> /tmp/tmp.ldif
	echo "description: Root node for hosts" >> /tmp/tmp.ldif

	ldapadd -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/tmp.ldif

	# Cleanup
	rm /tmp/tmp.ldif
}

###################
# USER MANAGEMENT #
###################

# Checks if a user is present
# Parameters: <username>
ldap_lookup_user () {
	ldapsearch -A -w "${BIND_PASSWORD}" -D "${BIND_DN}" \
		   -b "ou=Users,${BASE_DN}" cn=${1} | grep -v "#" | \
		   grep -i cn=${1} &> /dev/null
}

# Retrieve a user's info
# Parameters: <username>
ldap_get_user_info () {
	local IFS=$'\n'

	local UINFO=( `ldapsearch -w "${BIND_PASSWORD}" -D "${BIND_DN}" \
				  -b "ou=Users,${BASE_DN}" cn=${1} | \
				  grep -v "#" | grep ":"` )

	for (( i=0; i<${#UINFO[@]}; i++ )) ; do
		local TEMP=${UINFO[i]}
		IFS=": " read -r LDAP_ATTR LDAP_ATTR_VAL <<< ${TEMP}
		if [[ ${LDAP_ATTR} = "mail" ]] ; then
			LDAP_USER_MAIL=${LDAP_ATTR_VAL}
		elif [[ ${LDAP_ATTR} = "mobile" ]] ; then
			LDAP_USER_MOBILE=${LDAP_ATTR_VAL}
		elif [[ ${LDAP_ATTR} = "gecos" ]] ; then
			LDAP_USER_GECOS=${LDAP_ATTR_VAL}
		elif [[ ${LDAP_ATTR} = "shadowExpire" ]] ; then
			LDAP_USER_EXPIRED=1
		fi
	done
}

# Cleans up last set of LDAP_USER_x variables
# filled by ldap_get_user_info
ldap_clear_last_user_info () {
	LDAP_USER_MAIL=""
	LDAP_USER_MOBILE=""
	LDAP_USER_GECOS=""
	LDAP_USER_EXPIRED=0
}

# Adds a user
# Parameters: <username> <uid_num> <password>
ldap_add_user () {
	DN="cn=${1},ou=Users,${BASE_DN}"
	echo "version: 1" > /tmp/${1}.ldif
	echo "dn: ${DN}" >> /tmp/${1}.ldif
	echo "objectClass: account" >> /tmp/${1}.ldif
	echo "objectClass: shadowAccount" >> /tmp/${1}.ldif
	echo "objectClass: posixAccount" >> /tmp/${1}.ldif
	echo "objectClass: UocRadioUserInfo" >> /tmp/${1}.ldif
	echo "cn: ${1}" >> /tmp/${1}.ldif
	echo "uid: ${1}" >> /tmp/${1}.ldif
	echo "uidNumber: ${2}" >> /tmp/${1}.ldif
	echo "gidNumber: 100" >> /tmp/${1}.ldif
	echo "homeDirectory: /home/${1}" >> /tmp/${1}.ldif
	echo "localHomeDir: /home/default" >> /tmp/${1}.ldif
	echo "localUid: 1001" >> /tmp/${1}.ldif
	echo "loginShell: /bin/bash" >> /tmp/${1}.ldif
	echo "shadowLastChange: 0" >> /tmp/${1}.ldif
	echo "shadowMax: 0" >> /tmp/${1}.ldif
	echo "shadowWarning: 0" >> /tmp/${1}.ldif
	echo "shadowInactive: 0" >> /tmp/${1}.ldif

	ldapadd -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/${1}.ldif

	ldappasswd -s ${3} -w "${BIND_PASSWORD}" -D "${BIND_DN}" -x "${DN}"

	# Add user to the users group
	DN="cn=users,ou=User Groups,${BASE_DN}"
	echo "dn: ${DN}" > /tmp/${1}.ldif
	echo "changetype: modify" >> /tmp/${1}.ldif
	echo "add: memberuid" >> /tmp/${1}.ldif
	echo "memberuid: ${1}" >> /tmp/${1}.ldif

	ldapmodify -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/${1}.ldif


	# Add user to the library group
	DN="cn=library,ou=User Groups,${BASE_DN}"
	echo "dn: ${DN}" > /tmp/${1}.ldif
	echo "changetype: modify" >> /tmp/${1}.ldif
	echo "add: memberuid" >> /tmp/${1}.ldif
	echo "memberuid: ${1}" >> /tmp/${1}.ldif

	ldapmodify -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/${1}.ldif

	# Cleanup
	rm /tmp/${1}.ldif
}

# Deletes a user
# Parameters: <username>
ldap_delete_user () {
	# Delete user node
	ldapdelete -w "${BIND_PASSWORD}" -D "${BIND_DN}" \
		      "cn=${1},ou=Users,${BASE_DN}"

	# Delete user from the users group
	DN="cn=users,ou=User Groups,${BASE_DN}"
	echo "dn: ${DN}" > /tmp/${1}.ldif
	echo "changetype: modify" >> /tmp/${1}.ldif
	echo "delete: memberuid" >> /tmp/${1}.ldif
	echo "memberuid: ${1}" >> /tmp/${1}.ldif

	ldapmodify -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/${1}.ldif


	# Delete user from the library group
	DN="cn=library,ou=User Groups,${BASE_DN}"
	echo "dn: ${DN}" > /tmp/${1}.ldif
	echo "changetype: modify" >> /tmp/${1}.ldif
	echo "delete: memberuid" >> /tmp/${1}.ldif
	echo "memberuid: ${1}" >> /tmp/${1}.ldif

	ldapmodify -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/${1}.ldif


	# Delete user from the admins group
	DN="cn=admins,ou=User Groups,${BASE_DN}"
	echo "dn: ${DN}" > /tmp/${1}.ldif
	echo "changetype: modify" >> /tmp/${1}.ldif
	echo "delete: memberuid" >> /tmp/${1}.ldif
	echo "memberuid: ${1}" >> /tmp/${1}.ldif

	ldapmodify -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/${1}.ldif

	# Cleanup
	rm /tmp/${1}.ldif
}

# Adds a user to the admins group
# Parameters: <username>
ldap_set_user_admin () {
	DN="cn=admins,ou=User Groups,${BASE_DN}"
	echo "dn: ${DN}" > /tmp/${1}.ldif
	echo "changetype: modify" >> /tmp/${1}.ldif
	echo "add: memberuid" >> /tmp/${1}.ldif
	echo "memberuid: ${1}" >> /tmp/${1}.ldif

	ldapmodify -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/${1}.ldif

	# Cleanup
	rm /tmp/${1}.ldif
}

# Removes a user from the admins group
# Parameters: <username>
ldap_unset_user_admin () {
	DN="cn=admins,ou=User Groups,${BASE_DN}"
	echo "dn: ${DN}" > /tmp/${1}.ldif
	echo "changetype: modify" >> /tmp/${1}.ldif
	echo "delete: memberuid" >> /tmp/${1}.ldif
	echo "memberuid: ${1}" >> /tmp/${1}.ldif

	ldapmodify -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/${1}.ldif

	# Cleanup
	rm /tmp/${1}.ldif
}

# Disables a shadowAccount by marking it as expired
# Parameters: <username>
ldap_disable_shadowaccount () {
	DN="cn=${1},ou=Users,${BASE_DN}"
	echo "dn: ${DN}" > /tmp/${1}.ldif
	echo "changetype: modify" >> /tmp/${1}.ldif
	echo "replace: shadowExpire" >> /tmp/${1}.ldif
	echo "shadowExpire: 1" >> /tmp/${1}.ldif

	ldapmodify -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/${1}.ldif

	# Cleanup
	rm /tmp/${1}.ldif
}

# Re-enables an expired shadowAccount by removing the expiration mark
# Parameters: <username>
ldap_enable_shadowaccount () {
	DN="cn=${1},ou=Users,${BASE_DN}"
	echo "dn: ${DN}" > /tmp/${1}.ldif
	echo "changetype: modify" >> /tmp/${1}.ldif
	echo "delete: shadowExpire" >> /tmp/${1}.ldif

	ldapmodify -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/${1}.ldif

	# Cleanup
	rm /tmp/${1}.ldif
}

# Set a user's e-mail address
# Parameters: <username> <email>
ldap_set_user_email () {
	DN="cn=${1},ou=Users,${BASE_DN}"
	echo "dn: ${DN}" > /tmp/${1}.ldif
	echo "changetype: modify" >> /tmp/${1}.ldif
	echo "replace: mail" >> /tmp/${1}.ldif
	echo "mail: ${2}" >> /tmp/${1}.ldif

	ldapmodify -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/${1}.ldif

	# Cleanup
	rm /tmp/${1}.ldif
}

# Set a user's gecos field (real name/comments)
# Parameters: <username> <email>
ldap_set_user_gecos () {
	DN="cn=${1},ou=Users,${BASE_DN}"
	echo "dn: ${DN}" > /tmp/${1}.ldif
	echo "changetype: modify" >> /tmp/${1}.ldif
	echo "replace: gecos" >> /tmp/${1}.ldif
	echo "gecos: ${2}" >> /tmp/${1}.ldif

	ldapmodify -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/${1}.ldif

	# Cleanup
	rm /tmp/${1}.ldif
}

# Set a user's mobile number
# Parameters: <username> <mobile>
ldap_set_user_mobile () {
	DN="cn=${1},ou=Users,${BASE_DN}"
	echo "dn: ${DN}" > /tmp/${1}.ldif
	echo "changetype: modify" >> /tmp/${1}.ldif
	echo "replace: mobile" >> /tmp/${1}.ldif
	echo "mobile: ${2}" >> /tmp/${1}.ldif

	ldapmodify -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/${1}.ldif

	# Cleanup
	rm /tmp/${1}.ldif
}


###################
# HOST MANAGEMENT #
###################

# Adds a host node under Hosts and generates its
# configuration files under the ./hosts folder
# Parameters: <hostname> <ip address>
ldap_add_host () {
	# Create a random password
	local RANDOM_PASS=`head -n 1 /dev/urandom | tr -dc 'a-zA-Z0-9' | \
			   md5sum | awk '{print $1}'`

	# Create host with that random password
	DN="cn=${1},ou=Hosts,${BASE_DN}"
	echo "version: 1" > /tmp/${1}.ldif
	echo "dn: ${DN}" >> /tmp/${1}.ldif
	echo "objectClass: device" >> /tmp/${1}.ldif
	echo "objectClass: ipHost" >> /tmp/${1}.ldif
	echo "objectClass: simpleSecurityObject" >> /tmp/${1}.ldif
	echo "cn: ${1}" >> /tmp/${1}.ldif
	echo "ipHostNumber: ${2}" >> /tmp/${1}.ldif
	echo "userPassword: ${RANDOM_PASS}" >> /tmp/${1}.ldif

	ldapadd -x -w "${BIND_PASSWORD}" -D "${BIND_DN}" -f /tmp/${1}.ldif

	# Generate its config file based on a reference file
	mkdir -p ${LDAP_HOSTS_CONF_DIR}/${1}

	${SCRIPT_PATH}/generate_nss_ldap.conf.sh ${1} ${RANDOM_PASS}
	${SCRIPT_PATH}/generate_ldap.conf.sh ${1}

	# Cleanup
	rm /tmp/${1}.ldif
}

# Deletes a host node under Hosts and removes its
# configuration files under the ./hosts folder
# Parameters: <hostname>
ldap_delete_host () {
	ldapdelete -w "${BIND_PASSWORD}" -D "${BIND_DN}" \
		       "cn=${1},ou=Hosts,${BASE_DN}"
	rm -rf ${SCRIPT_PATH}/hosts/${1}
}

###########
# HELPERS #
###########

# Ask for bind dn's password
ldap_ask_bind_password () {
	echo "Bind Password:"
	read -s BIND_PASSWORD
}

# Set bind dn's password
ldap_set_bind_password () {
	BIND_PASSWORD=${1}
}
