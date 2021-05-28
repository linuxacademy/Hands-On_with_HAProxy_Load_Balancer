#!/bin/bash
# haproxy_monitoring_environment_setup.sh
# Script to create a backend container web farm for HAProxy lessons
# Enabling DDoS Attack Protection Using HAProxy section
# 5/28/2021 - Tom Dean

# Set the prompt
PS1="[\u@HAProxy \W]\$ " ; export PS1

# Install Software
# The first thing we need to do is install some software.
# We're going to be using Podman containers, so we'll install the `container-tools` package module. This will give us the tools we need to manage our containers.

# Install the `container-tools` package module
sudo yum -y module install container-tools

# We'll need to enable the `epel-release` repository
sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

# Next, we're going to install HAProxy and a few odds and ends
sudo yum -y install haproxy rsyslog httpd-tools figlet wget

# Download the HAProxy configuration file for the lesson and replace the stock configuration file
sudo bash -c 'cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.orig'
sudo curl https://raw.githubusercontent.com/linuxacademy/Hands-On_with_HAProxy_Load_Balancer/main/haproxy-monitoring.cfg -o /etc/haproxy/haproxy.cfg

# Download the `99-haproxy.conf` file for `rsyslog` to `/etc/rsyslog.d`
sudo curl https://raw.githubusercontent.com/linuxacademy/Hands-On_with_HAProxy_Load_Balancer/main/99-haproxy.conf -o /etc/rsyslog.d/99-haproxy.conf

# Create Some Test Files
# We're going to need some test files for our web server containers. We're going to use 6 containers in 2 groups of 3. We'll use the `figlet` command to spice up our text files a bit!

# Let's create the files
mkdir -p ~/testfiles
for site in `seq 1 2`; do for server in `seq 1 3`; do figlet -f big SITE$site - WEB$server > ~/testfiles/site$site\_server$server.txt ; done ; done

# Start Some Web Server Containers
# Ok, so now that we've got the odds and ends covered, let's stand up our web server containers. We're going to start a total of 6 `nginx` containers using Podman, simulating 2 sites, with 3 web servers per site. Our web servers will be available on ports `8081` through `8086`.

# Let's start our web containers
port=1 ; for site in `seq 1 2`; do for server in `seq 1 3`; do podman run -dt --name site$site\_server$server -p 808$(($port)):80 docker.io/library/nginx ; port=$(($port + 1 )) ; done ; done

# Copy Our Web Test Files
for site in `seq 1 2`; do for server in `seq 1 3`; do podman cp ~/testfiles/site$site\_server$server.txt site$site\_server$server:/usr/share/nginx/html/test.txt ; done ; done

# Generate a SSH key
ssh-keygen -q -t rsa -f ~/.ssh/id_rsa -N ""

# Create a SSH test file
mkdir ~/sshfiles
figlet -f big SSH-TEST > ~/sshfiles/ssh-test.txt

# Let's start our SSH container
podman run -dt --name sshd-server -p 2223:22 -v ${HOME}/.ssh/id_rsa.pub:/etc/authorized_keys/cloud_user:Z -v ${HOME}/sshfiles:/sshfiles:Z -e SSH_USERS="cloud_user:1001:1001" docker.io/panubo/sshd

# Add an empty /etc/haproxy/blocked.acl file
sudo touch /etc/haproxy/blocked.acl

# We need to set `haproxy_connect_any` to `1` make HAProxy work
sudo setsebool -P haproxy_connect_any 1

# Add some entries to /etc/hosts
sudo bash -c 'echo "# Local websites" >> /etc/hosts'
sudo bash -c 'echo "127.0.0.1       www.site1.com" >> /etc/hosts'
sudo bash -c 'echo "127.0.0.1       www.site2.com" >> /etc/hosts'
sudo bash -c 'echo "127.0.0.1       ssh.site3.com" >> /etc/hosts'

# In order to secure our sites, we're going to need SSL certificates. We can generate self-signed certificates using `openssl`. Make sure when you run the following commands that you set the `Common Name`, or hostname, to the correct site name. Use `www.site1.com` for site1 and `www.site2.com` for site2.

# Create a directory for our certificates
sudo mkdir /etc/haproxy/certs

# Generate 2 private keys
sudo openssl genrsa -out site1.key 2048
sudo openssl genrsa -out site2.key 2048

# Generate 2 Certificate Signing Requests
sudo openssl req -new -key site1.key -out site1.csr -subj '/C=US/ST=Illinois/L=Chicago/O=ACG/CN=www.site1.com'
sudo openssl req -new -key site2.key -out site2.csr -subj '/C=US/ST=Illinois/L=Chicago/O=ACG/CN=www.site1.com'

# Create 2 Self-Signed Certificates
sudo openssl x509 -req -days 365 -in site1.csr -signkey site1.key -out site1.crt
sudo openssl x509 -req -days 365 -in site2.csr -signkey site2.key -out site2.crt

# Append KEY and CRT to site1.pem and site2.pem
sudo bash -c 'cat site1.key site1.crt >> /etc/haproxy/certs/site1.pem'
sudo bash -c 'cat site2.key site2.crt >> /etc/haproxy/certs/site2.pem'

# Fix the self-signed certificate file permissions
sudo chmod 644 /etc/haproxy/ssl/*
sudo chmod 644 /etc/haproxy/certs/*

# Enable and start `haproxy` and `rsyslog`
sudo systemctl enable --now haproxy
sudo systemctl enable --now rsyslog

# Generate some traffic for our HAProxy logs
ab -n 100 -c 10 https://www.site1.com/ > ~/ab_site1.log > /dev/null 2>&1 &
ab -n 100 -c 10 https://www.site2.com/ > ~/ab_site2.log > /dev/null 2>&1 &
for conn in `seq 1 100` ; do bash -c 'scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 2222 cloud_user@ssh.site3.com:/sshfiles/ssh-test.txt . &' ; done > /dev/null 2>&1 &
for conn in `seq 1 100` ; do curl -k https://www.site1.com/ ; done > /dev/null 2>&1 &
for conn in `seq 1 100` ; do curl -k https://www.site2.com/ ; done > /dev/null 2>&1 &
for conn in `seq 1 100` ; do wget --no-check-certificate -O - https://www.site1.com/test.txt ; done > /dev/null 2>&1 &
for conn in `seq 1 100` ; do wget --no-check-certificate -O - https://www.site2.com/test.txt ; done > /dev/null 2>&1 &

# Checking our self-signed certificates
ls -al /etc/haproxy/certs/*

# Test Our Web Servers
port=1 ; for site in `seq 1 2`; do for server in `seq 1 3`; do curl -s http://127.0.0.1:808$port/test.txt ; port=$(($port + 1 )) ; done ; done | more

# Check our containers
podman ps -a

echo Container web farm created!
echo SSH server created!
