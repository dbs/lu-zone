#!/bin/bash
# Install DSpace from source, with Laurentian customizations

# Prerequisites:
# 1. Download DSpace source to a directory whose path is defined in DSPACE_SRC
# 2. Backup the /dspace/assetstore directory, and the database. Define
#    location/file name in DSPACE_DB_BACKUP and ASSETSTORE_BACKUP respectively
# 3. Download Laurentian customizations & link to DSpace source tree
#
#    Step 3 can be done by forking https://github.com/dbs/lu-zone 
#
#  cp -r lu-zone/config /path/to/dspace/src/dspace/
#  cp -r lu-zone/modules/ /path/to/dspace/src/dspace/
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

# Build a clean version of DSpace, with Maven.
mvn -U clean package

# Stop Tomcat, and then remove the old version of DSpace
sudo systemctl stop tomcat7
sudo rm -rf /dspace

# Delete the database tables and sequences.
psql -h postgres -U dspace dspace -t -c "select 'drop table \"' || tablename || '\" cascade;' from pg_tables where schemaname = 'public'"  | psql -h postgres -U dspace dspace
psql -h postgres -U dspace dspace -t -c "SELECT 'drop sequence ' || c.relname || ';' FROM pg_class c WHERE (c.relkind = 'S');" | psql dspace -h postgres -U dspace dspace

# Install DSpace using ant to /dspace
cd target/dspace-installer/
sudo ant fresh_install

# Copy over the backed up assetstore
sudo rm -rf /dspace/assetstore
sudo cp -r ${ASSETSTORE_BACKUP} /dspace/

# Restore the backed-up database
psql -h postgres -U dspace dspace < ${DSPACE_DB_BACKUP}

# Change the /jspui context path to /dspace
sudo mv /dspace/webapps/jspui/ /dspace/webapps/dspace/

# Set ownership of /dspace so tomcat can access dspace's files, and then deploy the webapps.
sudo chown -R tomcat7:tomcat7 /dspace
sudo cp -r /dspace/webapps/ /var/lib/tomcat7/

# Prepare the indices for searching.
sudo /dspace/bin/dspace index-lucene-init

# Clean cache and reimport data for OAI harvesting.
sudo /dspace/bin/dspace oai clean-cache
sudo /dspace/bin/dspace oai import

# Delete the default license so that localized ones are fallen back on.
sudo rm /dspace/config/default.license

# Restart tomcat7, and then use filter-media to create thumbnails for documents.
sudo systemctl start tomcat7
sudo /dspace/bin/dspace filter-media

# Done
echo "-----------------------"
echo "Done installing DSpace."
