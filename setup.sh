#!/bin/sh
set -e

sudo setenforce 0
sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/sysconfig/selinux

sudo yum -y install httpd php-mysql php php-gd php-mbstring php-xml mariadb mariadb-server curl unzip

sudo sed -i.orig 's/^;date.timezone =/date.timezone = Asia\/Tokyo/' /etc/php.ini

sudo sed -i.orig 's/^#\(ServerName www.example.com:80\)/\1/' /etc/httpd/conf/httpd.conf
sudo systemctl start httpd
sudo systemctl enable httpd

sudo systemctl start mariadb
sudo systemctl enable mariadb
sudo mysql_secure_installation <<EOF

n
y
y
y
y
EOF

# $ sudo mysql_secure_installation
# /bin/mysql_secure_installation: 行 379: find_mysql_client: コマンドが見つかりません
# 
# NOTE: RUNNING ALL PARTS OF THIS SCRIPT IS RECOMMENDED FOR ALL MariaDB
#       SERVERS IN PRODUCTION USE!  PLEASE READ EACH STEP CAREFULLY!
# 
# In order to log into MariaDB to secure it, we'll need the current
# password for the root user.  If you've just installed MariaDB, and
# you haven't set the root password yet, the password will be blank,
# so you should just press enter here.
# 
# Enter current password for root (enter for none):
# OK, successfully used password, moving on...
# 
# Setting the root password ensures that nobody can log into the MariaDB
# root user without the proper authorisation.
# 
# Set root password? [Y/n] n
#  ... skipping.
# 
# By default, a MariaDB installation has an anonymous user, allowing anyone
# to log into MariaDB without having to have a user account created for
# them.  This is intended only for testing, and to make the installation
# go a bit smoother.  You should remove them before moving into a
# production environment.
# 
# Remove anonymous users? [Y/n] y
#  ... Success!
# 
# Normally, root should only be allowed to connect from 'localhost'.  This
# ensures that someone cannot guess at the root password from the network.
# 
# Disallow root login remotely? [Y/n] y
#  ... Success!
# 
# By default, MariaDB comes with a database named 'test' that anyone can
# access.  This is also intended only for testing, and should be removed
# before moving into a production environment.
# 
# Remove test database and access to it? [Y/n] y
#  - Dropping test database...
#  ... Success!
#  - Removing privileges on test database...
#  ... Success!
# 
# Reloading the privilege tables will ensure that all changes made so far
# will take effect immediately.
# 
# Reload privilege tables now? [Y/n] y
#  ... Success!
# 
# Cleaning up...
# 
# All done!  If you've completed all of the above steps, your MariaDB
# installation should now be secure.
# 
# Thanks for using MariaDB!

mysql -uroot -Dmysql <<EOF
create database wordpress;
grant all on wordpress.* to wordpress identified by 'password';
EOF

curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
chmod +x /usr/local/bin/wp

sudo /usr/local/bin/wp core download --path=/var/www/html/ --locale=ja
sudo /usr/local/bin/wp core config --path=/var/www/html/ --dbname=wordpress --dbuser=wordpress --dbpass=password --dbhost=localhost --locale=ja
sudo /usr/local/bin/wp core install --path=/var/www/html/ --url=http://192.168.33.18 --title='ワードプレスのテスト' --admin_name=admin --admin_email=admin@example.com --admin_password=test
sudo /usr/local/bin/wp plugin update --path=/var/www/html/ --all
sudo /usr/local/bin/wp plugin install wordpress-importer --path=/var/www/html/ --activate

curl -LO https://raw.github.com/jawordpressorg/theme-test-data-ja/master/wordpress-theme-test-date-ja.xml
sudo /usr/local/bin/wp import --path=/var/www/html/ --authors=create wordpress-theme-test-date-ja.xml
rm wordpress-theme-test-date-ja.xml

sudo chown -R apache: /var/www/html/*
