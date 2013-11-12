#!/bin/sh
 
##### INFO #####

# provision.sh
#
# This script will provision a clean Ubuntu 12.04 LTS 64bit Vagrant box to be
# used for drupal 7 development.
# 
# Author: Arradi Nur Rizal


#=============================START CONFIGURATION===============================

# Server name
HOSTNAME="vagrant.dcl"

# MySQL password, 
# you should change it (note:storing password in a script is bad)
MYSQL_PASS="root" 

# Locale
# See http://docs.moodle.org/dev/Table_of_locales for other locale
LOCALE_LANGUAGE="en_US" 
LOCALE_CODESET="en_US.UTF-8"

# Timezone
# see http://manpages.ubuntu.com/manpages/jaunty/man3/DateTime::TimeZone::Catalog.3pm.html
TIMEZONE="Asia/Jakarta"

# Drush will be downloaded from drupal.org
DRUSH_VERSION="5.9.0"

#=============================END CONFIGURATION=================================


#=============================PROVISION CHECK===================================

# Checking if the box has been provisioned or not, so we do not do it twice
# The way we do it is by creating a file that indicate the box has been provisioned
# The file to check is .provision_done. Delete the file if you change the configuration
echo "[provisioning] Checking if the box has been provisioned.........."

if [ -e "/home/vagrant/.provision_done" ]
then
  # Skip provision if the box has been provisioned
  echo "[provisioning] The box has been provisioned.........."
  exit
fi


#=============================PROVISION LAMP and more ==========================

echo "[provisioning] Installing LAMP stack, git, memcache, apc.........."

# Set Locale
echo "[provisioning] Setting locale.........."
sudo locale-gen $LOCALE_LANGUAGE $LOCALE_CODESET

# Set timezone
echo "[provisioning] Setting timezone.........."
echo $TIMEZONE | sudo tee /etc/timezone
sudo dpkg-reconfigure --frontend noninteractive tzdata

# Download and update package lists
echo "[provisioning] Package manager updates.........."
sudo apt-get update

# Install or update nfs-common to the latest release on Ubuntu
echo "[provisioning] Installing nfs-common.........."
sudo apt-get install -y nfs-common

# Install development package for development environment
echo "[provisioning] Installing development environment.........."

# Version control tools
echo "[provisioning] Installing git.........."
sudo apt-get install -y git # GIT

# Set MySQL root password and install MySQL.
echo mysql-server mysql-server/root_password select $MYSQL_PASS | debconf-set-selections
echo mysql-server mysql-server/root_password_again select $MYSQL_PASS | debconf-set-selections
echo "[provisioning] Installing mysql-server and mysql-client.........."
sudo apt-get install -y mysql-server mysql-client
sudo service mysql restart 

# Install Apache
echo "[provisioning] Installing apache2.........."
sudo apt-get install -y apache2 
sudo service apache2 restart 
a2enmod rewrite # enable mod_rewrite for drupal clean url
a2enmod actions # actions
sudo service apache2 restart

# Install PHP
echo "[provisioning] Installing PHP.........."
sudo apt-get install -y php5 php5-cli php5-common php5-curl php5-gd php5-mysql php5-memcache
sudo service apache2 restart 

# Caching package
echo "[provisioning] Installing memcache.........."
sudo apt-get install memcached libmemcached-tools -y #install memcache
echo "[provisioning] Installing APC.........."
sudo apt-get install php-apc -y #install apc
sudo service apache2 restart
#downloding apc.php
wget -O /home/vagrant/sites apc.php "http://git.php.net/?p=pecl/caching/apc.git;a=blob_plain;f=apc.php;hb=HEAD"

#=============================PROVISION OTHER PACKAGE ==========================

echo "[provisioning] Installing other packages.........."

# Postfix
echo "[provisioning] Installing postfix.........."
echo postfix postfix/mailname string $HOSTNAME | debconf-set-selections
echo postfix postfix/main_mailer_type string 'Internet Site' | debconf-set-selections
sudo apt-get install -y postfix
service postfix reload

# Misc tools
echo "[provisioning] Installing curl, make, openssl, nano, unzip..."

sudo apt-get install -y curl 
sudo apt-get install -y make 
sudo apt-get install -y openssl 
sudo apt-get install -y php5-dev
sudo a2enmod ssl 
sudo apt-get install -y unzip 
sudo apt-get install -y nano # Nano

# Install Drush by wget
echo "[provisioning] Installing drush..."
# download drush from github
sudo wget -q https://github.com/drush-ops/drush/archive/$DRUSH_VERSION.tar.gz 
# untar drush in /opt
sudo tar -C /opt/ -xzf $DRUSH_VERSION.tar.gz 
# ensure the vagrant user has sufficient rights
sudo chown -R vagrant:vagrant /opt/drush-$DRUSH_VERSION
# add drush to /usr/sbin 
sudo ln -s /opt/drush-$DRUSH_VERSION/drush /usr/sbin
# remove the downloaded tarbal 
sudo rm -rf /home/vagrant/sites/$DRUSH_VERSION.tar.gz  

# Install xhprof
echo "[provisioning] Installing xhprof..."
sudo wget -q https://github.com/facebook/xhprof/archive/master.zip
sudo unzip /home/vagrant/master.zip
cd /home/vagrant/xhprof-master/extension
sudo phpize
sudo ./configure
make
make install
echo "extension=xhprof.so" >> /etc/php5/conf.d/xhprof.ini
echo "xhprof.output_dir=/tmp" >> /etc/php5/conf.d/xhprof.ini
cd -
sudo rm -f /home/vagrant/master.zip
sudo service apache2 restart


#====================================CONFIGURATION=============================

echo "[provisioning] Configuring vagrant box..."
# adds vagrant user to www-data group
usermod -a -G vagrant www-data 

# Hostname
echo "[provisioning] Setting hostname..."
sudo hostname $HOSTNAME

# Change document root to vagrant sites
rm -rf /var/www
ln -fs /vagrant/sites /var/www

#====================================CLEAN UP==================================

# try to resolve some issue when upgrads/install does not run properly
sudo dpkg --configure -a 

# remove obsolete packages
sudo apt-get autoremove -y 


#==================================PROVISION CHECK==============================

# Create .provision_check for the script to check on during a next vargant up.
echo "[provisioning] Creating .provision_done file..."
touch .provision_done