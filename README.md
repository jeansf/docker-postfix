docker-postfix
==============

run postfix with smtp authentication (sasldb) in a docker container.
TLS, OpenDKIM and Certbot (Cloudflare) support are optional.

## Requirement
+ Docker 1.0

## Installation
1. Build image

	```bash
	$ sudo docker pull jeansf/postfix
	```

## Usage
1. Create postfix container with smtp authentication

	```bash
	$ sudo docker run -p 25:25 \
			-e maildomain=mail.example.com -e smtp_user=user:pwd \
			--name postfix -d jeansf/postfix
	# Set multiple user credentials: -e smtp_user=user1:pwd1,user2:pwd2,...,userN:pwdN
	```
2. Enable OpenDKIM: save your domain key ```mail.exmple.com.private``` in ```/path/to/domainkeys```

	```bash
	$ sudo docker run -p 25:25 \
			-e maildomain=mail.example.com -e smtp_user=user:pwd \
			-v /path/to/domainkeys:/etc/opendkim/domainkeys \
			--name postfix -d jeansf/postfix
	```
3. Enable TLS(587): save your SSL certificates ```live/mail.exmple.com/fullchain.pem``` and ```live/mail.exmple.com/privkey.pem``` to  ```/path/to/certs``` like a letsencrypt structure

	```bash
	$ sudo docker run -p 587:587 \
			-e maildomain=mail.example.com -e smtp_user=user:pwd \
			-e enable_tls=true
			-v /path/to/certs:/etc/letsencrypt \
			--name postfix -d jeansf/postfix
	```
4. Enable TLS(587) with Certbot (Cloudflare): renew certificate enabled in this option

	```bash
	$ sudo docker run -p 587:587 \
			-e maildomain=mail.example.com -e smtp_user=user:pwd \
			-e enable_tls=true -e cloudflare_api_token=TOKEN
			-v /path/to/certs:/etc/letsencrypt \
			--name postfix -d jeansf/postfix
	```
## Note
+ Login credential should be set to (`username@mail.example.com`, `password`) in Smtp Client
+ You can assign the port of MTA on the host machine to one other than 25 ([postfix how-to](http://www.postfix.org/MULTI_INSTANCE_README.html))
+ Read the reference below to find out how to generate domain keys and add public key to the domain's DNS records

## Reference
+ [Postfix SASL Howto](http://www.postfix.org/SASL_README.html)
+ [How To Install and Configure DKIM with Postfix on Debian Wheezy](https://www.digitalocean.com/community/articles/how-to-install-and-configure-dkim-with-postfix-on-debian-wheezy)

## Code Attribution

The code in this project is based on or includes code snippets from the following source:

- **Original Project**: [catatnight/docker-postfix](https://github.com/catatnight/docker-postfix)
