<!--
SPDX-FileCopyrightText: 2024 Joe Pitt

SPDX-License-Identifier: GPL-3.0-only
-->
# bind9 certbot deploy hook

Deploy hook for certbot to install certificate into bind9 for DoT and DoH support.

The hook:

1. Copies the full chain and private key to a directory readable by bind9, including setting
    ownership and permissions.
2. Creates a `tls certbot-tls { ... };` configuration block pointing to the certificates.
3. Ensures there are IPv4 and IPv6 listeners for DNS, DNS over TLS (DoT), and DNS over HTTPS (DoH).
    Configuring DoT and DoH to use the `tls certbot-tls` settings.
4. Reloads bind9 to pick up the configuration changes / new certificate.

## Install

Copy `bind9-deploy-hook.sh` to the bind9 server, e.g. into `/usr/local/sbin/`.

Ensure HTTP (80/tcp) is allowed through the firewall from the ACME server for the challenge to work.

## Usage

To use the deploy hook for the initial issuance, and all subsequent auto-renewals, request the
initial certificate as follows:

```sh
certbot certonly --standalone --domain ns1.domain.tld \
    --deploy-hook /usr/local/sbin/bind9-deploy-hook.sh 
```

All being well the output will look something like:

```
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Requesting a certificate for ns1.domain.tld
Hook 'deploy-hook' ran with output:
 bind9 certbot deploy hook v1.0.0

 Installing certificate file
 Installing private key file
 Adding certbot TLS config block to /etc/bind/named.conf.options
 Configuring IPv4 and IPv6 DNS (53/udp & 53/tcp), DoT (853/tcp), and DoH (443/tcp) listeners in /etc/bind/named.conf.options
 Reloading bind9
 Done

Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/ns1.domain.tld/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/ns1.domain.tld/privkey.pem
This certificate expires on 2024-09-27.
These files will be updated when the certificate renews.
Certbot has set up a scheduled task to automatically renew this certificate in the background.

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
If you like Certbot, please consider supporting our work by:
 * Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
 * Donating to EFF:                    https://eff.org/donate-le
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
```

Your named.conf.options will now have these lines in (plus any existing config):

```conf
tls certbot-tls {
        cert-file "/etc/bind/bind.crt";
        key-file "/etc/bind/bind.key";
};

options {
        listen-on { any; };
        listen-on-v6 { any; };
        listen-on port 443 tls certbot-tls http default { any; };
        listen-on-v6 port 443 tls certbot-tls http default { any; };
        listen-on port 853 tls certbot-tls { any; };
        listen-on-v6 port 853 tls certbot-tls { any; };
};
```

## Other OSes

The hook has been written on Ubuntu, some variables may need to be tweaked for other OSes.

* `BIND_CONF` needs to point to the appropriate bind9 configuration file for `tls` and `options`
    settings, on Ubuntu this is `/etc/bind/named.conf.options`.
* `BIND_USER` and `BIND_GROUP` need to reference the user and group bind9 runs as, on Ubuntu this is
    `bind` for both, others are known to use `named`.
* `CERT_TARGET` and `PRIVATE_KEY_TARGET` need to point to file paths the user bind9 run as can read.

## Notes

Currently the hook does not configure these settings in the `certbot-tls` config block:

* `dhparam-file`
* `cipher-suites`
* `ciphers`
* `prefer-server-ciphers`
* `session-tickets`

Refer to the
[bind9 documentation](https://bind9.readthedocs.io/en/latest/reference.html#tls-block-definition-and-usage)
and [Mozilla Security/Server Side TLS guidance](https://wiki.mozilla.org/Security/Server_Side_TLS)
to configure them manually if desired.
