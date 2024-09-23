#!/bin/bash

# set common options for connection to the JS7 REST Web Service
request_options=(--url=http://joc-2-0-primary.sos:7446 --user=root --password=root --controller-id=testsuite --ca-cert=./root-ca.crt)

# ------------------------------ Status ----------

# get status information
./operate-joc.sh status "${request_options[@]}"

# ------------------------------ License ----------

# check license
./operate-joc.sh check-license "${request_options[@]}"

# ------------------------------ Encrypted Passwords ----------

# create Private Key
openssl ecparam -name secp384r1 -genkey -noout -out ./ca/private/encrypt.key

# create Certificate Signing Request
openssl req -new -sha512 -nodes -key ./ca/private/encrypt.key -out ./ca/csr/encrypt.csr -subj "/C=DE/ST=Berlin/L=Berlin/O=SOS/OU=IT/CN=Encrypt"

# create Certificate
openssl x509 -req -sha512 -days 1825 -signkey ./ca/private/encrypt.key -in ./ca/csr/encrypt.csr -out ./ca/certs/encrypt.crt -extfile <(printf "keyUsage=critical,keyEncipherment,keyAgreement\n")

# encrypt
result=$(./operate-joc.sh encrypt --in=root --cert=./ca/certs/encrypt.crt --java-home=/opt/java/jdk-21)

# set common options for connection to the JS7 REST Web Service
request_options=(--url=http://joc-2-0-primary.sos:7446 --user=root --password="enc:BEz9kY/z3D5e2RFZKL8m58c9ZpWY68kHGNMS9/Vkbj86aGjgqmMHURquLwIppu78sOZtrNWzpAFswrvvd3fTSGjwFYa1EpU43K5JTDq2x7NdXSE5djHmnJC3BFZikorfj/3W+nPEa7WYjUULS/sz/DBTBb3mWCjQcdP/y2k8QJ3WQzgYiQ== PjHY/QQcs2LYbMivSYjBLg== RjoPa/0xkdSTr8ogXUd3tA==" --key=./ca/private/encrypt.key --java-home=/opt/java/jdk-21 --controller-id=testsuite --ca-cert=./root-ca.crt)

# check license
./operate-joc.sh check-license "${request_options[@]}"
