# Let' s Encrypt Smart Renewal with Staging
Bash script for renewing Let's Encrypt certificates including a staging period

# Description
This script was created to make renewing Let's Encrypt certificates as easy and smoothly as possible. It checks for an expiring certificate every day and if necessary fetches a new one from Let's Encrypt via the `acme-tiny.py` script. It is to be kept as a staging certificate until the production certificate is about to expire very soon. At that point the production certificate gets replaced by the staging one and services are automatically reloaded for changes to take effect.

This procedure avoids issues with new certificates being "too new" if a client's system time differs by a certain amount. How much can be defined by `$RENEWSTAGING` (default is set to 1 week) and the `$RENEWPRODUCTION` (default is set to 3 days).

Keep in mind, however, that the first number alone would only account for negative deviations, when the client's time is late, e.g. "still in the past". If the client's time is early, e.g. "already in the future", you will only get the benefit of `$RENEWPRODUCTION`. Therefore I picked 3 days, so the client can be 7-3=4 days "late" and 3 days "early".

# Requirements and how to run it
In order for this script to work you need to meet the following criteria:

1. A folder structure like mentioned in the script, otherwise change it appropriately in the environment variables at the beginning of the script to match your needs. Since I am using a custom user for my ACME business, I set these folders up in its home directory. By default you need to have the following folders.
	- `scripts/` contains the `acme-tiny.py` script as well as this script itself
	- `csr/` contains the CSRs for your certificates
	- `certs/` contains the signed certificates for staging and production
	- `/var/www/acme-challenges` this is the default folder where `acme-tiny.py` will put the challenges for Let's Encrypt to verify the domain (see 4. for details)
2. Make sure that the `certs` folder is readable by the services that need the signed certificates, otherwise a reload will fail. A simple `chmod -R 644 certs` inside the main folder could do the trick for you.
3. `acme-tiny.py` from https://github.com/diafygi/acme-tiny to be put into the `scripts` folder
4. The necessary requirements to run it, according to Scott Helme's tutorial: https://scotthelme.co.uk/setting-up-le/ (these are mainly the private RSA key and the CSR for your certificates but also setting up the webserver for the ACME-challenges, for naming these files see 10.)
5. Change the `$DOMAINS` array appropriately so your files have an appropriate name. If you have more than one domain, enter them like in the example with spaced strings. It's usually a good idea to use the FQDN that you entered in your CSRs.
6. Make sure that the user running this script is allowed to reload the services. Depending on your operating system and services that use the certificates, you might be able to do that by adding the following lines to your `/etc/sudoers` file: (example for Debian/Ubuntu)

        acme    ALL=NOPASSWD: /usr/sbin/service apache2 reload
        acme    ALL=NOPASSWD: /usr/sbin/service postfix reload
        acme    ALL=NOPASSWD: /usr/sbin/service dovecot reload

7. Before you can run the script you need to either set the `INTERMEDIATE` flag to false, if you don't want a intermediate PEM certificate file or put the intermediate certificate file provided by your CA into the `certs/` folder. Note that an intermediate certificate is required for Let's Encrypt and most other CAs but it might not be needed in your setup if you have a service that reads this file separately and not as a part of the main certificate.
8. When you run the script for the first time, the working files won't exist yet. In order to fix that, you need run it yourself once (as the user) with the command line argument `firstrun`. You can do so by running for example this: `sudo -u acme /home/acme/scripts/renew.sh firstrun` (replace `acme` with the appropriate username and of course the corresponding path). The `firstrun` flag can also be used to force a fresh certificate straight from Let's Encrypt all the way to production.
9. Set up a cron job for the user running the script to run it once per day. You can do so by running `crontab -e -u acme` (replace `acme` with the username you run it as) and add the desired job. For example this runs it at 3:33am every day and writes the output to `/var/log/acme_tiny.log`. If you don't mind an email every 3 months confirming the progress, you can remove the rest of the line starting from and including `>>` (given that you have a working mail system on the machine that is configured to work with `crond`).

        33  3   *   *   *    /home/acme/scripts/renew.sh >> /var/log/acme_tiny.log

10. By default, the working files are named like follows:
	- `account.key` is the Let's Encrypt account key you provided, put it in the same folder like the script
	- `example.com.csr` is the CSR using RSA for "example.com" you provided
	- `example.com-ecdsa.csr` is the CSR using ECDSA for "example.com" you provided
	- `staging-example.com.crt` is the staging certificate using RSA for "example.com"
	- `example.com.crt` is the production certificate using RSA for "example.com"
	- `staging-example.com-ecdsa.crt` is the staging certificate using ECDSA for "example.com"
	- `example.com-ecdsa.crt` is the production certificate using ECDSA for "example.com"

Thanks for taking a look or even using my script! It's still a work in progress and more like a template, though it can be used as is in many instances.

If you have any suggestions, feel free to let me know!
