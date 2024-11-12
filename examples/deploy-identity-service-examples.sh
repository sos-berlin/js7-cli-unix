#!/bin/bash

# set common options for connection to the JS7 REST Web Service
request_options=(--url=https://centostest-primary.sos:6446 --user=root --password=root --ca-cert=./root-ca.crt)

# ------------------------------ Accounts ----------

# get list of accounts
./deploy-identity-service.sh get-account             "${request_options[@]}" --service=JOC-INITIAL

# get account
./deploy-identity-service.sh get-account             "${request_options[@]}" --service=JOC-INITIAL --account=test-account

# store account using initial password
./deploy-identity-service.sh store-account           "${request_options[@]}" --service=JOC-INITIAL --account=test-account

# store account with specific password
./deploy-identity-service.sh store-account           "${request_options[@]}" --service=JOC-INITIAL --account=test-account \
                                                     --account-password=secret

# trigger password change for account on next login
./deploy-identity-service.sh store-account           "${request_options[@]}" --service=JOC-INITIAL --account=test-account \
                                                     --force-password-change

# get account permissions
./deploy-identity-service.sh get-account-permission  "${request_options[@]}" --service=JOC-INITIAL --account=test-account

# set account password
./deploy-identity-service.sh set-account-password    "${request_options[@]}" --service=JOC-INITIAL --account=test-account --account-password=secret --new-password=very-secret

# reset account to use initial password
./deploy-identity-service.sh reset-account-password  "${request_options[@]}" --service=JOC-INITIAL --account=test-account

# enable account
./deploy-identity-service.sh enable-account          "${request_options[@]}" --service=JOC-INITIAL --account=test-account

# disable account
./deploy-identity-service.sh disable-account         "${request_options[@]}" --service=JOC-INITIAL --account=test-account

# rename account
./deploy-identity-service.sh rename-account          "${request_options[@]}" --service=JOC-INITIAL --account=test-account --new-account=test-account2

# remove account
./deploy-identity-service.sh remove-account          "${request_options[@]}" --service=JOC-INITIAL --account=test-account2

# remove accounts
./deploy-identity-service.sh remove-account          "${request_options[@]}" --service=JOC-INITIAL --account=test-account1,test-account2


# get blocked accounts
./deploy-identity-service.sh get-account             "${request_options[@]}" --service=JOC-INITIAL --blocked

# block account
./deploy-identity-service.sh block-account           "${request_options[@]}" --service=JOC-INITIAL --account=test-account1

# unblock account
./deploy-identity-service.sh unblock-account         "${request_options[@]}" --service=JOC-INITIAL --account=test-account1,test-account2

# ------------------------------ Roles ----------

# get roles
./deploy-identity-service.sh get-role                "${request_options[@]}" --service=JOC-INITIAL

# get role
./deploy-identity-service.sh get-role                "${request_options[@]}" --service=JOC-INITIAL --role=administrator

# store role
./deploy-identity-service.sh store-role              "${request_options[@]}" --service=JOC-INITIAL --role=new-role

# rename role
./deploy-identity-service.sh rename-role             "${request_options[@]}" --service=JOC-INITIAL --role=new-role --new-role=new-role-new

# remove role
./deploy-identity-service.sh remove-role             "${request_options[@]}" --service=JOC-INITIAL --role=new-role-new

# remove roles
./deploy-identity-service.sh remove-role             "${request_options[@]}" --service=JOC-INITIAL --role=new-role-new,new-role

# ------------------------------ Permissions ----------

# get permissions for role
./deploy-identity-service.sh get-permission          "${request_options[@]}" --service=JOC-INITIAL --role=new-role

# assign permissions to role
./deploy-identity-service.sh set-permission          "${request_options[@]}" --service=JOC-INITIAL --role=new-role --permission='sos:products:controller:view','sos:products:controller:agents:view'

# rename permission
./deploy-identity-service.sh rename-permission       "${request_options[@]}" --service=JOC-INITIAL --role=new-role \
                                                                --permission='sos:products:controller:agents:view' \
                                                                --new-permission='sos:products:controller:deployment:view' --excluded

# remove permission
./deploy-identity-service.sh remove-permission       "${request_options[@]}" --service=JOC-INITIAL --role=new-role --permission='sos:products:controller:deployment:view'

# ------------------------------ Folder Permissions ----------

# get folder permissions for all folders assigned the indicated role
./deploy-identity-service.sh get-folder              "${request_options[@]}" --service=JOC-INITIAL --role=new-role

# get folder permissions for the indicated role and folder
./deploy-identity-service.sh get-folder              "${request_options[@]}" --service=JOC-INITIAL --role=new-role --folder=/myFolder

# set folder permissions recursively for a number of folders
./deploy-identity-service.sh set-folder              "${request_options[@]}" --service=JOC-INITIAL --role=new-role --folder=/myFolder

# rename folder permissions
./deploy-identity-service.sh rename-folder           "${request_options[@]}" --service=JOC-INITIAL --role=new-role --folder=/myFolder --new-folder=/myFolder2 --recursive

# remove folder permissions
./deploy-identity-service.sh remove-folder           "${request_options[@]}" --service=JOC-INITIAL --role=new-role --folder=/myFolder2

# ------------------------------ Identity Services ----------

# get Identity Service
./deploy-identity-service.sh get-service             "${request_options[@]}"

# get Identity Service
./deploy-identity-service.sh get-service             "${request_options[@]}" --service=JOC-INITIAL

# store Identity Service
./deploy-identity-service.sh store-service "${request_options[@]}" --service=New-Service --service-type=OIDC

# store Identity Service with second factor
./deploy-identity-service.sh store-service "${request_options[@]}" --service=New-Service --service-type=OIDC --second-service=JOC-INITIAL

# store required Identity Service using password for single-factor authentication
./deploy-identity-service.sh store-service "${request_options[@]}" --service=New-Service --service-type=LDAP --authentication-scheme=SINGLE-FACTOR

# store required Identity Service using two-factor authentication
./deploy-identity-service.sh store-service "${request_options[@]}" --service=FIDO-Service --service-type=FIDO
./deploy-identity-service.sh store-service "${request_options[@]}" --service=LDAP-Service --service-type=LDAP --authentication-scheme=TWO-FACTOR

# rename Identity Service
./deploy-identity-service.sh rename-service          "${request_options[@]}" --service=New-Service --new-service=New-Service-New

# remove Identity Service
./deploy-identity-service.sh remove-service          "${request_options[@]}" --service=New-Service

# ------------------------------ Setting up JOC Identity Management ----------

# create Identity Service using password for single-factor authentication
./deploy-identity-service.sh store-service "${request_options[@]}" --service=My-Service --service-type=JOC \
                                           --authentication-scheme=SINGLE-FACTOR

# create roles
./deploy-identity-service.sh store-role "${request_options[@]}" --service=My-Service --role=developer
./deploy-identity-service.sh store-role "${request_options[@]}" --service=My-Service --role=operator
 
# assign permissions to roles
./deploy-identity-service.sh set-permission "${request_options[@]}" --service=My-Service --role=developer \
                                            --permission='sos:products:joc:administration:view','sos:products:joc:auditlog:view','sos:products:joc:calendars:view','sos:products:joc:cluster','sos:products:joc:inventory','sos:products:controller:view','sos:products:controller:agents:view'
 
./deploy-identity-service.sh set-permission "${request_options[@]}" --service=My-Service --role=operator\
                                            --permission='sos:products:joc:auditlog:view','sos:products:joc:calendars:view','sos:products:joc:cluster:view','sos:products:controller:view','sos:products:controller:agents:view'
 
# create accounts and assign roles
./deploy-identity-service.sh store-account  "${request_options[@]}" --service=My-Service --account=dev --role=developer
./deploy-identity-service.sh store-account  "${request_options[@]}" --service=My-Service --account=ops --role=operator

# remove Identity Service
./deploy-identity-service.sh remove-service "${request_options[@]}" --service=My-Service

# ------------------------------ Setting up LDAP Identity Management ----------

# create Identity Service using password for single-factor authentication
./deploy-identity-service.sh store-service "${request_options[@]}" --service=My-Service --service-type=LDAP \
                                           --authentication-scheme=SINGLE-FACTOR

# get settings from an existing Identity Service
#     store settings to an environment variable
# settings=$(./deploy-identity-service.sh get-service-settings "${request_options[@]}" --service=My-Service --service-type=LDAP)
#     store settings to a file
# ./deploy-identity-service.sh get-service-settings "${request_options[@]}" --service=My-Service --service-type=LDAP > ./examples/ldap-settings.json
#     read settings from a file
# settings=$(cat ./examples/ldap-settings.json)
 
# create roles
./deploy-identity-service.sh store-role "${request_options[@]}" --service=My-Service --role=developer
./deploy-identity-service.sh store-role "${request_options[@]}" --service=My-Service --role=operator
 
# assign permissions to roles
./deploy-identity-service.sh set-permission "${request_options[@]}" --service=My-Service --role=developer \
                                            --permission='sos:products:joc:administration:view','sos:products:joc:auditlog:view','sos:products:joc:calendars:view','sos:products:joc:cluster','sos:products:joc:inventory','sos:products:controller:view','sos:products:controller:agents:view'
 
./deploy-identity-service.sh set-permission "${request_options[@]}" --service=My-Service --role=operator\
                                            --permission='sos:products:joc:auditlog:view','sos:products:joc:calendars:view','sos:products:joc:cluster:view','sos:products:controller:view','sos:products:controller:agents:view'
 
# create accounts and assign roles
./deploy-identity-service.sh store-account  "${request_options[@]}" --service=My-Service --account=dev --role=developer
./deploy-identity-service.sh store-account  "${request_options[@]}" --service=My-Service --account=ops --role=operator

# remove Identity Service
./deploy-identity-service.sh remove-service "${request_options[@]}" --service=My-Service
