#!/usr/bin/env bash

PODCIDR=$(ip route | grep 'cilium_host src' | awk '{print $1}')

cat <<EOF > /etc/quagga/bgpd.conf
hostname zebra-bgpd
password zebra
enable password zebra
!
log file /var/log/quagga/bgpd.log
!
debug bgp events
debug bgp filters
debug bgp fsm
debug bgp keepalives
debug bgp updates
!
router bgp 64512
bgp graceful-restart
maximum-paths 4
maximum-paths ibgp 4
network $PODCIDR
neighbor 192.168.10.254 remote-as 64513
!
line vty
EOF

chown quagga:quagga /etc/quagga/bgpd.conf
chmod 640 /etc/quagga/bgpd.conf
systemctl enable bgpd && systemctl start bgpd
