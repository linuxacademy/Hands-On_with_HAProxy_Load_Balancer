#!/bin/bash
# haproxy-fill-logs.sh
# Script to create a traffic to fill HAProxy logs with data
# Troubleshooting HAProxy Issues lab
# 6/30/2021 - Tom Dean

# Run ApacheBench tests
ab -n 1000 -c 10 https://www.site1.com/ > ~/ab_site1.log > /dev/null 2>&1 &
ab -n 1000 -c 10 https://www.site2.com/ > ~/ab_site2.log > /dev/null 2>&1 &
ab -n 1000 -c 10 https://www.site1.com/test.txt > ~/ab_site1_test.log > /dev/null 2>&1 &
ab -n 1000 -c 10 https://www.site2.com/test.txt > ~/ab_site2_test.log > /dev/null 2>&1 &

# Run curl tests
for conn in `seq 1 1000` ; do curl -k https://www.site1.com/ ; done > /dev/null 2>&1 &
for conn in `seq 1 1000` ; do curl -k https://www.site2.com/ ; done > /dev/null 2>&1 &
for conn in `seq 1 1000` ; do curl -k https://www.site1.com/test.txt ; done > /dev/null 2>&1 &
for conn in `seq 1 1000` ; do curl -k https://www.site2.com/test.txt ; done > /dev/null 2>&1 &

# Run wget tests
for conn in `seq 1 1000` ; do wget --no-check-certificate -O - https://www.site1.com/ ; done > /dev/null 2>&1 &
for conn in `seq 1 1000` ; do wget --no-check-certificate -O - https://www.site2.com/ ; done > /dev/null 2>&1 &
for conn in `seq 1 1000` ; do wget --no-check-certificate -O - https://www.site1.com/test.txt ; done > /dev/null 2>&1 &
for conn in `seq 1 1000` ; do wget --no-check-certificate -O - https://www.site2.com/test.txt ; done > /dev/null 2>&1 &

# Run SSH test
for conn in `seq 1 100` ; do bash -c 'scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 2222 cloud_user@ssh.site3.com:/sshfiles/ssh-test.txt . > /dev/null 2>&1 &' ; done &
