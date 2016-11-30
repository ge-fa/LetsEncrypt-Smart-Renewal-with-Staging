#!/bin/bash

# Check if the user set the firstrun flag:
if [ "$1" = "firstrun" ]; then
	read -p "Firstrun/Forcerun requested. Do you want that? (y/n) " choice
	case "$choice" in
		y|Y ) FIRSTRUN=true;;
		n|N ) FIRSTRUN=false;;
		* ) echo "Invalid option! Exiting..."; exit 1;;
	esac
else
	FIRSTRUN=false
fi

# Paths of certificates, scripts, CSRs and ACME-challenges:
CERTS="/home/acme/certs"
SCRIPTS="/home/acme/scripts"
ACCOUNTKEY="$SCRIPTS/account.key"
CSRS="/home/acme/csr"
CHALLENGESDIR="/var/www/acme-challenges"

# If you have an intermediate certificate that you would like to create
# a PEM file with, set the next variable to true and put the certificates into
# the certs/ folder like "intermediate-example.com.pem" for "example.com".
# This is necessary for Let's Encrypt and most other CAs unless your services
# load it separately and not as a part of the main certificate file.
# Note that you need an intermediate certificate file for each domain. If you
# have many domains consider chainging the code by e.g. hardcoding the name.
INTERMEDIATE=true

# Domain names for referring to the files (usually the FQDN from your CSRs):
declare -a DOMAINS=("www.example.com" "www2.example.com");

# Get a new certificate for preparation in 7 days:
RENEWSTAGING=7
# Swap the production certificate for staging one 3 days before expiration:
RENEWPRODUCTION=3
# RELOAD set to true if production certificates get changed
RELOAD=false

# Do you want RSA certificates? If so, set to true:
RSA=true
# Do you want ECDSA certificates? If so, set to true:
ECDSA=true

# Check if all necessary directories are readable
if [ ! -r "$CSRS" ]; then
	date -Iseconds | tr -d '\n'
	echo " CSR directory ($CSRS) is not readable! Exiting..."
	exit 1
fi
if [ ! -r "$SCRIPTS" ]; then
	date -Iseconds | tr -d '\n'
	echo " Script directory ($SCRIPTS) is not readable! Exiting..."
	exit 1
fi
if [ ! -r "$CERTS" ]; then
	date -Iseconds | tr -d '\n'
	echo " Certificate directory ($SCRIPTS) is not readable! Exiting..."
	exit 1
fi

# Check if all necessary directories are writable
if [ ! -w "$CHALLENGESDIR" ]; then
	date -Iseconds | tr -d '\n'
	echo " Web directory for ACME challenges ($CHALLENGESDIR) is not writable! Exiting..."
	exit 1
fi
if [ ! -w "$CERTS" ]; then
	date -Iseconds | tr -d '\n'
	echo " Certificate directory 'certs' ($CERTS) is not writable! Exiting..."
	exit 1
fi

# Check if all necessary files exist and are readable or executable
if [ ! -r "$ACCOUNTKEY" ]; then
	date -Iseconds | tr -d '\n'
	echo " Let's Encrypt ACME 'account.key' does not exist in 'scripts' directory ($SCRIPTS)! Exiting..."
	exit 1
fi
if [ ! -x "$SCRIPTS/acme_tiny.py" ]; then
	date -Iseconds | tr -d '\n'
	echo " 'acme_tiny.py' script does not exist in 'scripts' directory ($SCRIPTS)! Exiting..."
	exit 1
fi
for DOMAIN in "${DOMAINS[@]}"; do
	if [ ! -r "$CSRS/$DOMAIN.csr" ]; then
		date -Iseconds | tr -d '\n'
		echo " CSR for $DOMAIN does not exist in CSR directory ($CSRS)! Exiting..."
		exit 1
	fi
done

# Check each domain for renewal
for DOMAIN in "${DOMAINS[@]}"; do
	if $RSA; then
		if $FIRSTRUN || ! openssl x509 -checkend $[ 86400 * $RENEWSTAGING ] -noout -in $CERTS/staging-$DOMAIN.crt; then
			# Staging certificate expires soon, getting a new one
			date -Iseconds | tr -d '\n' && echo " Staging certificate (RSA) for $DOMAIN expires soon, getting a new one."
			python $SCRIPTS/acme_tiny.py --account-key $ACCOUNTKEY \
				--csr $CSRS/$DOMAIN.csr --acme-dir $CHALLENGESDIR \
				> $CERTS/staging-$DOMAIN.crt || exit 1
		fi
		if $FIRSTRUN || ! openssl x509 -checkend $[ 86400 * $RENEWPRODUCTION ] -noout -in $CERTS/$DOMAIN.crt; then
			# Production certificate expires very soon,
			# replacing production certificate with staging certificate:
			date -Iseconds | tr -d '\n' && echo " Production certificate (RSA) for $DOMAIN expires very soon, replacing production certificate with staging certificate."
			cp $CERTS/staging-$DOMAIN.crt $CERTS/$DOMAIN.crt
			# Production certificate changed, reload necessary:
			RELOAD=true
		fi
	fi

	if $ECDSA; then
		if $FIRSTRUN || ! openssl x509 -checkend $[ 86400 * $RENEWSTAGING ] -noout -in $CERTS/staging-$DOMAIN-ecdsa.crt; then
			# Staging certificate expires soon, getting a new one
			date -Iseconds | tr -d '\n' && echo " Staging certificate (ECDSA) for $DOMAIN expires soon, getting a new one."
			python $SCRIPTS/acme_tiny.py --account-key $ACCOUNTKEY \
				--csr $CSRS/$DOMAIN-ecdsa.csr --acme-dir $CHALLENGESDIR \
				> $CERTS/staging-$DOMAIN-ecdsa.crt || exit 1
		fi
		if $FIRSTRUN || ! openssl x509 -checkend $[ 86400 * $RENEWPRODUCTION ] -noout -in $CERTS/$DOMAIN-ecdsa.crt; then
			# Production certificate expires very soon,
			# replacing production certificate with staging certificate:
			date -Iseconds | tr -d '\n' && echo " Production certificate (ECDSA) for $DOMAIN expires very soon, replacing production certificate with staging certificate."
			cp $CERTS/staging-$DOMAIN-ecdsa.crt $CERTS/$DOMAIN-ecdsa.crt
			# Production certificate changed, reload necessary:
			RELOAD=true
		fi
	fi
done

# If reload is necessary, replace PEM style certificates with new staging
# certificates and reload services
if $RELOAD; then
	# Make new PEM style certificates (certificate + intermediate) if requested
	date -Iseconds | tr -d '\n' && echo -n " Creating new PEM style certificates.. "
	if $INTERMEDIATE; then
		for DOMAIN in "${DOMAINS[@]}"; do
			cat $CERTS/$DOMAIN.crt $CERTS/intermediate-$DOMAIN.pem > $CERTS/$DOMAIN.pem
			cat $CERTS/$DOMAIN-ecdsa.crt $CERTS/intermediate-$DOMAIN.pem > $CERTS/$DOMAIN-ecdsa.pem
		done
	fi
	echo "done."
	# Reload services
	date -Iseconds | tr -d '\n' && echo " Reloading services..."
	sudo service apache2 reload
	sudo service postfix reload
	sudo service dovecot reload
fi
