#!/bin/sh
set -e

sudo setenforce 0
sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/sysconfig/selinux

sudo yum -y install httpd php-mysql php php-gd php-mbstring php-xml mariadb mariadb-server curl unzip

sudo sed -i.orig 's/^;date.timezone =/date.timezone = Asia\/Tokyo/' /etc/php.ini

sudo systemctl start mariadb
sudo systemctl enable mariadb
mysql -uroot -Dmysql <<EOF
/* rootのパスワードを設定します。 */
set password for root@localhost=password('roothoge');
/* hoge というユーザを新規に作成します。のパスワードも設定します。 */
insert into user set user="hoge", password=password("hogehoge"), host="localhost";
/* wddb というwordpress用にデータベースを作成します。 */
create database wddb;
/* wddb というデータベースに hogeというユーザが常にアクセスできるようにします。 */
grant all on wddb.* to hoge;
/* 最新に更新 */
FLUSH PRIVILEGES;
EOF

sudo sed -i.orig 's/^#\(ServerName www.example.com:80\)/\1/' /etc/httpd/conf/httpd.conf
sudo systemctl start httpd
sudo systemctl enable httpd
#sudo sh -c "echo '<?php echo phpinfo(); ?>' > /var/www/html/index.php"

curl -LO https://ja.wordpress.org/wordpress-4.3.1-ja.zip
unzip -q wordpress-4.3.1-ja.zip
sudo mv wordpress/* /var/www/html/
sudo sed -i "s/extension_loaded( 'simplexml' )/false \&\& &/" /var/www/html/wp-content/plugins/wordpress-importer/parsers.php
sudo chown -R apache: /var/www/html/*
rmdir wordpress
