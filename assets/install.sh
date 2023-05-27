#!/bin/bash

mkdir -p /etc/opendkim/domainkeys /etc/letsencrypt/
rm -Rf /etc/cron.*/*

#judgement
if [[ -a /etc/supervisor/conf.d/supervisord.conf ]]; then
  exit 0
fi

#supervisor
cat > /etc/supervisor/conf.d/supervisord.conf <<EOF
[supervisord]
nodaemon=true
user=root

[program:postfix]
command=/opt/postfix.sh

[program:cron]
command=cron -f
EOF

############
#  postfix
############
cat >> /opt/postfix.sh <<EOF
#!/bin/bash
if pidof -x master >/dev/null; then
  service postfix restart
else
  service postfix start
fi
tail -f /var/log/mail.log
EOF
chmod +x /opt/postfix.sh
postconf -e myhostname=$maildomain
postconf -F '*/*/chroot = n'
postconf -e maillog_file=/var/log/mail.log

############
# SASL SUPPORT FOR CLIENTS
# The following options set parameters needed by Postfix to enable
# Cyrus-SASL support for authentication of mail clients.
############
# /etc/postfix/main.cf
postconf -e smtpd_sasl_auth_enable=yes
postconf -e broken_sasl_auth_clients=yes
postconf -e smtpd_recipient_restrictions=permit_sasl_authenticated,reject_unauth_destination
# smtpd.conf
cat >> /etc/postfix/sasl/smtpd.conf <<EOF
pwcheck_method: auxprop
auxprop_plugin: sasldb
mech_list: PLAIN LOGIN CRAM-MD5 DIGEST-MD5 NTLM
EOF
# sasldb2
echo $smtp_user | tr , \\n > /tmp/passwd
while IFS=':' read -r _user _pwd; do
  echo $_pwd | saslpasswd2 -p -c -u $maildomain $_user
done < /tmp/passwd
chown postfix.sasl /etc/sasldb2

############
# Enable TLS
############
if [ "$enable_tls" = true ] ; then
  # /etc/postfix/main.cf
  postconf -e smtpd_tls_cert_file=/etc/letsencrypt/live/$maildomain/fullchain.pem
  postconf -e smtpd_tls_key_file=/etc/letsencrypt/live/$maildomain/privkey.pem
  # /etc/postfix/master.cf
  postconf -M submission/inet="submission   inet   n   -   n   -   -   smtpd"
  postconf -P "submission/inet/syslog_name=postfix/submission"
  postconf -P "submission/inet/smtpd_tls_security_level=encrypt"
  postconf -P "submission/inet/smtpd_sasl_auth_enable=yes"
  postconf -P "submission/inet/milter_macro_daemon_name=ORIGINATING"
  postconf -P "submission/inet/smtpd_recipient_restrictions=permit_sasl_authenticated,reject_unauth_destination"
fi

############
# Cloudflare credentials
############
if [ ! -z "$cloudflare_api_token" ] ; then
  echo "dns_cloudflare_api_token = \"$cloudflare_api_token\"" > /etc/letsencrypt/credentials
  chmod 0600 /etc/letsencrypt/credentials

  if [ ! -f "/etc/letsencrypt/live/$maildomain/fullchain.pem" ]; then
     certbot certonly --non-interactive --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/credentials --agree-tos --register-unsafely-without-email -d $maildomain --post-hook "supervisorctl restart postfix"
  fi

cat >> /etc/cron.daily/certbot <<EOF
#!/bin/bash

certbot renew --non-interactive --no-self-upgrade --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/credentials --agree-tos --post-hook "supervisorctl restart postfix"
EOF
fi

#############
#  opendkim
#############

if [[ -z "$(find /etc/opendkim/domainkeys -iname *.private)" ]]; then
  exit 0
fi
cat >> /etc/supervisor/conf.d/supervisord.conf <<EOF

[program:opendkim]
command=/usr/sbin/opendkim -f
EOF
# /etc/postfix/main.cf
postconf -e milter_protocol=2
postconf -e milter_default_action=accept
postconf -e smtpd_milters=inet:localhost:12301
postconf -e non_smtpd_milters=inet:localhost:12301

cat >> /etc/opendkim.conf <<EOF
AutoRestart             Yes
AutoRestartRate         10/1h
UMask                   002
Syslog                  yes
SyslogSuccess           Yes
LogWhy                  Yes

Canonicalization        relaxed/simple

ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts
InternalHosts           refile:/etc/opendkim/TrustedHosts
KeyTable                refile:/etc/opendkim/KeyTable
SigningTable            refile:/etc/opendkim/SigningTable

Mode                    sv
PidFile                 /var/run/opendkim/opendkim.pid
SignatureAlgorithm      rsa-sha256

UserID                  opendkim:opendkim

Socket                  inet:12301@localhost
EOF
cat >> /etc/default/opendkim <<EOF
SOCKET="inet:12301@localhost"
EOF

cat >> /etc/opendkim/TrustedHosts <<EOF
127.0.0.1
localhost
email
192.168.0.1/24

$maildomain
*.$maildomain
EOF
cat >> /etc/opendkim/KeyTable <<EOF
mail._domainkey.$maildomain $maildomain:mail:$(find /etc/opendkim/domainkeys -iname *.private)
EOF
cat >> /etc/opendkim/SigningTable <<EOF
*@$maildomain mail._domainkey.$maildomain
EOF
chown opendkim:opendkim $(find /etc/opendkim/domainkeys -iname *.private)
chmod 400 $(find /etc/opendkim/domainkeys -iname *.private)