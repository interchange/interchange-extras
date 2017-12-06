# set your local /etc/resolv.conf to include:
#  nameserver 127.0.0.1
#
# then run this command as root:

dnsmasq --address=/.test/127.0.0.1 --local-service
