#!/bin/bash

gateway="connect.vpn.indeed.com"
#Enter IPSec gateway address: connect.vpn.indeed.com

groupId="Indeed"
#Enter IPSec ID for connect.vpn.indeed.com: Indeed

read -sp 'Group Password: ' groupSecret
echo
#Enter IPSec secret for Indeed@connect.vpn.indeed.com:

username="adevore"
#Enter username for connect.vpn.indeed.com: adevore

read -sp 'User Password: ' userSecret
echo
#Enter password for adevore@connect.vpn.indeed.com:

sudo vpnc <<!
$gateway
$groupId
$groupSecret
$username
$userSecret
!

