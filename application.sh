#!/bin/bash

apt-get update -qy
apt-get install apache2 libapache2-mod-php5 -y

DB_IP=${DB_IP:-127.0.0.1}

cd /var/www/

git clone -q https://github.com/manageacloud/example-php.git

cat >/etc/apache2/sites-enabled/example.conf <<EOL
<VirtualHost _default_:80>
DocumentRoot /var/www/example-php
SetEnv DB $DB_IP
<Directory /var/www/>
Options Indexes FollowSymLinks MultiViews
AllowOverride All
Order allow,deny
allow from all
</Directory>
</VirtualHost>
EOL

rm -f /etc/apache2/sites-enabled/000-default.conf

/etc/init.d/apache2 restart

