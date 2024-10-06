#!/bin/bash
yum install -y openvpn easy-rsa

# Set up the CA and generate server certificates
make-cadir /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa
./easyrsa init-pki
echo -ne '\n' | ./easyrsa build-ca nopass
./easyrsa gen-req server nopass
echo -ne '\n' | ./easyrsa sign-req server server
./easyrsa gen-dh

# Copy files to the OpenVPN directory
cp pki/private/server.key /etc/openvpn/
cp pki/issued/server.crt /etc/openvpn/
cp pki/ca.crt /etc/openvpn/
cp pki/dh.pem /etc/openvpn/

# Create server configuration
cat <<EOL > /etc/openvpn/server.conf
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
cipher AES-256-CBC
persist-key
persist-tun
status openvpn-status.log
verb 3
EOL

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

# Start and enable OpenVPN service
systemctl start openvpn@server
systemctl enable openvpn@server
