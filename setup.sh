#! /bin/sh

mkdir /tmp/test
cd /tmp/test
git init
echo "Initial file for temp project" > one_file.txt
git add one_file.txt
git commit -m "First Commit"

mkdir /tmp/test.git
cd /tmp/
git clone --bare /tmp/test

ip addr list
