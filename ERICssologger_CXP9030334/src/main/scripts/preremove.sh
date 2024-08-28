#
# RPM pre remove scriptlet for SSO Logger
#

APACHE_CERT_DIR=/ericsson/tor/data/certificates/sso
APACHE_CERT_PREFIX=ssoserverapache
PKI_CERT_DIR=/etc/pki/tls/certs/
PKI_KEY_DIR=/etc/pki/tls/private/

LOGGER_TAG="ERICssologger preun"
##
## INFORMATION print
##
info()
{
	if [ ${#} -eq 0 ]; then
		while read data; do
			logger -s -t TOR_SSO_PA -p user.notice "INFORMATION ( ${LOGGER_TAG} ): ${data}"
		done
	else
		logger -s -t TOR_SSO_PA -p user.notice "INFORMATION ( ${LOGGER_TAG} ): $@"
	fi
}

## ERROR print
##
error()
{
	if [ ${#} -eq 0 ]; then
		while read data; do
			logger -s -t TOR_SSO_PA -p user.err "ERROR ( ${LOGGER_TAG} ): ${data}"
		done
	else
		logger -s -t TOR_SSO_PA -p user.err "ERROR ( ${LOGGER_TAG} ): $@"
	fi
}

if [ $1 -eq 0 ]; then
	info "Argument to rpm 'preun' scriptlet is 0: this should only show when there are no more packages to be installed"
fi

info "Cleanup complete"

exit 0