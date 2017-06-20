# Account Management stuff

On UoC Radio we have a PHPBB forum to communicate with each other and organize various events, shows, tasks etc. Since PHPBB already has a registration form and a user management system, and since our members were already using it we decided to use it as the basis for maintaining and administrating user accounts globaly.

The idea is to have an LDAP server that gets in sync with the forum's database, this includes new users, inactive users, re-activated users etc. Unfortunately since PHPBB uses a different hash algorithm for passwords than openldap, we can't sync passwords at the moment but it's a first step. However that's not a real issue since LDAP passwords are only used for local logins, for remote logins we use certificate based authentication, both for VPN (x509 Certificates) and ssh (ssh certificates).

Along the LDAP two certificate authorities are maintained, tha main one is an x509 CA that signs certificates for our services (e.g. LDAP, VPN) and also client certificates for VPN access. The other one is an SSH CA that signs user certificates that can be used for ssh access on our hosts. Both CAs maintain revocation lists so that if an account gets disabled by the forum, not only the coresponding LDAP account will be disabled, but the user's certificates will also get revoked so VPN and SSH access won't be possible. The SSH CA uses the main CA's certificate indices and basicaly re-signs the public key of the x509 certs. This way the user only needs to generate one key pair and only send one CSR. The CSRs are generated inside the browser using csr_generator, user keeps the private key localy and submits the CSR through an extra profile field on the forum.

All of the above hapen on an OpenWRT box, so everything is done through bash and the available command line tools.

The sync process can be seen on sync_to_forum.sh, it goes like this:
* Management server (an OpenWRT box) connects to the web server (that also acts as a certificate/CRL distribution point) and runs ulistquery (inside helper scripts). It gets back an XML with the user profile fields, including the CSR field.
* User details (username, real name, phone number, mail etc) are synced with LDAP, if a user is inactive, it's marked as inactive on LDAP too, if it's a new user it gets created, if it's an old user that's re-activated, it gets re-activated on LDAP too.
* If user has provided a CSR, the CSR is signed and a new x509 certificate is generated. From the CSR's/certificate's public key, an SSH certificate is also generated and signed. Both certificates are put on a bundle file (a tar.xz) and uploaded to the web server (under the /ca directory), which as mentioned above acts also as a cert/CRL distribution point.
* If the user is inactive both x509 and SSH certificates get revoked and the crls get updated. If it's re-activated, we manualy modify its entry on the main CA's database (index file) and re-generate both CRLs.

