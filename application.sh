#!/bin/bash

# install apache and php
apt-get update -qy
apt-get install apache2 libapache2-mod-php5 -y

# Read the system environment variables with the parameters
DB_IP=${DB_IP:-127.0.0.1}
APP_BRANCH=${APP_BRANCH:-master}

# clone the git repository that contains the application
cd /var/www/
git clone -q https://github.com/manageacloud/example-php.git

# checkout the required branch
cd /var/www/example-php/
git checkout origin/$APP_BRANCH

# configure the virtual host
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

