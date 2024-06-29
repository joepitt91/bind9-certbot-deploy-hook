#!/bin/bash

# SPDX-FileCopyrightText: 2024 Joe Pitt
#
# SPDX-License-Identifier: GPL-3.0-only

BIND_CONF=/etc/bind/named.conf.options
BIND_USER=bind
BIND_GROUP=bind
CERT_TARGET=/etc/bind/bind.crt
PRIVATE_KEY_TARGET=/etc/bind/bind.key

CERT_FILE=${RENEWED_LINEAGE}/fullchain.pem
PRIVATE_KEY_FILE=${RENEWED_LINEAGE}/privkey.pem
TLS_OPTIONS="tls certbot-tls {\n        cert-file \"$CERT_TARGET\";\n        key-file \"$PRIVATE_KEY_TARGET\";\n};\n"
LISTEN_OPTIONS='options {\n        listen-on { any; };\n        listen-on-v6 { any; };\n        listen-on port 443 tls certbot-tls http default { any; };\n        listen-on-v6 port 443 tls certbot-tls http default { any; };\n        listen-on port 853 tls certbot-tls { any; };\n        listen-on-v6 port 853 tls certbot-tls { any; };'

set -e
echo "bind9 certbot deploy hook v1.0.0"
echo

echo "Installing certificate file"
cp "$CERT_FILE" "$CERT_TARGET"
chown $BIND_USER:$BIND_GROUP "$CERT_TARGET"
chmod 644 "$CERT_TARGET"

echo "Installing private key file"
cp "$PRIVATE_KEY_FILE" "$PRIVATE_KEY_TARGET"
chown $BIND_USER:$BIND_GROUP "$PRIVATE_KEY_TARGET"
chmod 600 "$PRIVATE_KEY_TARGET"

if [ "$(grep -c -P '^tls certbot-tls {$' $BIND_CONF)" == "0" ]; then
    echo "Adding certbot TLS config block to $BIND_CONF"
    sed -i "1s|^|$TLS_OPTIONS|" $BIND_CONF
fi

echo "Configuring IPv4 and IPv6 DNS (53/udp & 53/tcp), DoT (853/tcp), and DoH (443/tcp) listeners in $BIND_CONF"
if [ "$(grep -c -P '^options {$' $BIND_CONF)" == "0" ]; then
    echo "$LISTEN_OPTIONS};" >>$BIND_CONF
else
    sed -i -E "/^( |\t)*listen-on/d" $BIND_CONF
    sed -i -E "s|options \{|$LISTEN_OPTIONS|" $BIND_CONF
fi

echo "Reloading bind9"
rndc reconfig

echo "Done"
