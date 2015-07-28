#!/bin/bash
# Install DSpace from source, with Laurentian customizations


# Prerequisites:
# 1. Download DSpace source to a directory whose path is defined in DSPACE_SRC
# 2. Backup the /dspace/assetstore directory, and the database. Define
#    location/file name in DSPACE_DB_BACKUP and ASSETSTORE_BACKUP respectively
# 3. Download Laurentian customizations & link to DSpace source tree
# 4. Download UNB customizations for the use of the ETDMS crosswalk
#
#    Steps 2&3 can be done by forking github.com/kbeswick/lu-zone &
#    github.com/kbeswick/unb-dspace , then:
#
#  ln -s lu-zone/config /path/to/dspace/src/dspace/config
#  ln -s lu-zone/modules/jspui /path/to/dspace/src/dspace/modules/jspui
#
#  ... and following the instructions under the 'Metadata crosswalks' section of
#  the Readme of the unb-dspace repository
#
# DISCLAIMER:
#
# This script is currently intended as more of a guide, rather than an automation of
# the installation process, although under the right conditions it should work.

# This script assumes that the version of Tomcat that the server is running is Tomcat 7.


DSPACE_SRC='/path/to/dspace/src'
DSPACE_DB_BACKUP='/path/to/dspace_database.dump'
ASSETSTORE_BACKUP='/path/to/assetstore'

cp -r modules/ ${DSPACE_SRC}/dspace/
cp -r config/ ${DSPACE_SRC}/dspace/

cd ${DSPACE_SRC}/dspace/

# Build a clean version of DSpace
mvn -U clean package

# Stop Tomcat, remove the old version of DSpace
sudo systemctl stop tomcat7
sudo rm -rf /dspace

# Delete and create empty database for fresh DSpace install
sudo su -c "dropdb dspace ; createdb -U dspace -E UNICODE dspace" postgres

# Install DSpace
cd target/dspace-installer/
sudo ant fresh_install

# Copy over the backed up assetstore
sudo rm -rf /dspace/assetstore
sudo cp -r ${ASSETSTORE_BACKUP} /dspace/

# Recreate the database with backed up version
sudo su -c "cd /var/lib/postgresql && dropdb dspace && createdb -U dspace -E UNICODE dspace && psql dspace < ${DSPACE_DB_BACKUP}" postgres

# Be consistent with our previous DSpace URLS
sudo ln -s /dspace/webapps/oai /dspace/webapps/dspace-oai
sudo ln -s /dspace/webapps/jspui /dspace/webapps/dspace

# Set permissions for /dspace
sudo chown -R tomcat7:tomcat7 /dspace

# Prepare the indexes, media
sudo /dspace/bin/dspace index-init
sudo systemctl restart tomcat7
sudo /dspace/bin/dspace filter-media

# Done
echo "-----------------------"
echo "Done installing DSpace."

