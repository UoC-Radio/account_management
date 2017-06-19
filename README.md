# Account Management stuff

On UoC Radio we have a PHPBB forum to communicate with each other and organize various events, shows, tasks etc.
Since PHPBB already has a registration form and a user management system, and since our members were already using it we decided to use
it as the basis for maintaining and administrating user accounts globaly.

The idea is to have an LDAP server that gets in sync with the forum's database, this includes new users, inactive users, re-activated users
etc. Unfortunately since PHPBB uses a different hash algorithm for passwords than openldap, we can't sync passwords at the moment but it's a
first step. However that's not a real issue since LDAP passwords are only used for local logins, for remote logins we use certificate based
authentication, both for the VPN (X509 Certificates) and the ssh (ssh certificates).

Along the LDAP two certificate authorities are maintained, tha main one is an x509 CA that signs certificates for our services (e.g. LDAP, VPN)
and also client certificates for VPN access. The other one is an SSH CA that signs user certificates that can be used for ssh access on
our hosts. Both CAs maintain revocation lists so that if an account gets disabled by the forum, not only the coresponding LDAP
account will be disabled, but the user's certificates will also get revoked so VPN and SSH access won't be possible. The SSH CA uses the
main CA's certificate indices and basicaly re-signs the public key of the X509 certs.

(WiP)

