#!/bin/bash
#
# This script configures:
# - BDR master to master postgres replication in postgres 9.4
# - 'demo' database
# - 'postgres' authentication using ssl certificates
# - ability to create new master-to-master databases or joining existing ones
#

# Read variables
PUBLIC_IP=${PUBLIC_IP:-127.0.0.1}
MASTER_IP=${MASTER_IP:-}
NODENAME=`hostname`

# installs postgres BDR
curl -sSL https://manageacloud.com/api/cm/configuration/postgresql-bdr/debian/manageacloud-production-script.sh | bash

# create bdr database
su - postgres -c "/usr/lib/postgresql/9.4/bin/initdb -D /var/lib/postgresql/bdr/ -A trust -U postgres"

# Configure auth cert in postgres (server side)
cp unsecure_cert/server.key /var/lib/postgresql/bdr/server.key
cp unsecure_cert/server.crt /var/lib/postgresql/bdr/server.crt
cp unsecure_cert/root.crt /var/lib/postgresql/bdr/root.crt
chown -R postgres:postgres /var/lib/postgresql/bdr/
chmod 600 /var/lib/postgresql/bdr/server.key

# Configure auth cert in postgres (client side)
mkdir /var/lib/postgresql/.postgresql/
cp unsecure_cert/postgresql.key /var/lib/postgresql/.postgresql/
cp unsecure_cert/postgresql.crt /var/lib/postgresql/.postgresql/
cp unsecure_cert/root.crt /var/lib/postgresql/.postgresql/
chown -R postgres:postgres /var/lib/postgresql/.postgresql/
chmod 600 /var/lib/postgresql/.postgresql/postgresql.key

# enable BDR
sed -i "s/#shared_preload_libraries = ''/shared_preload_libraries = 'bdr'/g" /var/lib/postgresql/bdr/postgresql.conf
sed -i 's/#wal_level = minimal/wal_level = 'logical'/g'  /var/lib/postgresql/bdr/postgresql.conf
sed -i 's/#track_commit_timestamp = off/track_commit_timestamp = on/g' /var/lib/postgresql/bdr/postgresql.conf
sed -i 's/#max_wal_senders = 0/max_wal_senders = 10/g' /var/lib/postgresql/bdr/postgresql.conf
sed -i 's/#max_replication_slots = 0/max_replication_slots = 10/g' /var/lib/postgresql/bdr/postgresql.conf
sed -i 's/#max_worker_processes = 8/max_worker_processes = 10/g' /var/lib/postgresql/bdr/postgresql.conf

# manage auth and permissions
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '0.0.0.0'/g" /var/lib/postgresql/bdr/postgresql.conf
sed -i "s/#ssl = off/ssl = on/g" /var/lib/postgresql/bdr/postgresql.conf
sed -i "s/#ssl_ca_file = ''/ssl_ca_file = 'root.crt'/g" /var/lib/postgresql/bdr/postgresql.conf
sed -i 's/#local/local/g' /var/lib/postgresql/bdr/pg_hba.conf
sed -i 's/#host/host/g' /var/lib/postgresql/bdr/pg_hba.conf
echo >> /var/lib/postgresql/bdr/pg_hba.conf 
echo "hostssl    demo            postgres       0.0.0.0/0            cert clientcert=1" >> /var/lib/postgresql/bdr/pg_hba.conf
echo "hostssl    replication     postgres       0.0.0.0/0            cert clientcert=1" >> /var/lib/postgresql/bdr/pg_hba.conf

# start postgres
su - postgres -c "/usr/lib/postgresql/9.4/bin/pg_ctl -l /var/log/postgresql/bdr.log -D /var/lib/postgresql/bdr -w start"

# create database
su - postgres -c "createdb demo"
psql -U postgres demo -c "CREATE EXTENSION btree_gist;"
psql -U postgres demo -c "CREATE EXTENSION bdr;"

# enable master to master replication
if [ "$MASTER_IP" != "" ]; then
  # join to master
  apt-get -yq install netcat 
  TIMEOUT=0
  while ! nc -z $MASTER_IP 5432; do
    if (( $TIMEOUT>500 )); then
      echo "Timeout: Error while waiting to master to be active"
      exit 1
    fi
    TIMEOUT=$[$TIMEOUT+1]
    sleep 1
  done
  
  # make sure master database is initialized
  sleep 10 
  
  # join
  psql -U postgres demo -c "SELECT bdr.bdr_group_join(local_node_name := '$NODENAME',node_external_dsn := 'host=$PUBLIC_IP dbname=demo sslcert=/var/lib/postgresql/.postgresql/postgresql.crt sslkey=/var/lib/postgresql/.postgresql/postgresql.key sslrootcert=/var/lib/postgresql/.postgresql/root.crt user=postgres', join_using_dsn := 'host=$MASTER_IP dbname=demo sslcert=/var/lib/postgresql/.postgresql/postgresql.crt sslkey=/var/lib/postgresql/.postgresql/postgresql.key sslrootcert=/var/lib/postgresql/.postgresql/root.crt user=postgres');"

else
  # create the first master
  psql -U postgres demo -c "SELECT bdr.bdr_group_create(local_node_name := '$NODENAME',node_external_dsn := 'host=$PUBLIC_IP dbname=demo sslcert=/var/lib/postgresql/.postgresql/postgresql.crt sslkey=/var/lib/postgresql/.postgresql/postgresql.key sslrootcert=/var/lib/postgresql/.postgresql/root.crt user=postgres');"
fi

psql -U postgres demo -c "SELECT bdr.bdr_node_join_wait_for_ready();"


