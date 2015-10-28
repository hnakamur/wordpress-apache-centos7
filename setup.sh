#!/bin/bash
set -e

usage_exit() {
  cat <<EOF 1>&2
Usage: ${0##*/} [OPTIONS]
  This script setup Apache, MariaDB and Wordpress, then import Japanese test data for WordPress.

Options:
  -h, --help  print this option
  --db-name WORDPRESS_DB_NAME
  --db-user WORDPRESS_DB_USER
  --db-password WORDPRESS_DB_PASSWORD
  --site-host SITE_HOST
  --site-title SITE_TITLE
  --admin-name ADMIN_NAME
  --admin-emal ADMIN_EMAIL
  --admin-password ADMIN_PASSWORD
EOF
  exit 1
}

OPT=`getopt -o h --long help,db-name:,db-user:,db-password:,site-host:,site-title:,admin-name:,admin-email:,admin-password: -- "$@"`
if [ $? != 0 ] ; then
  usage_exit
fi
eval set -- "$OPT"

# default values
db_name=wordpress
db_user=wordpress
db_password=password
site_host="example.com"
site_title="ワードプレスのテスト"
admin_name='admin'
admin_email="admin@example.com"
admin_password='password'

while true
do
    case "$1" in
    --db-name)
    	db_name="$2" 
        shift 2
        ;;
    --db-user)
    	db_user="$2" 
        shift 2
        ;;
    --db-password)
    	db_password="$2" 
        shift 2
        ;;
    --site-host)
    	site_host="$2" 
        shift 2
        ;;
    --site-title)
    	site_title="$2" 
        shift 2
        ;;
    --admin-name)
    	admin_name="$2" 
        shift 2
        ;;
    --admin-email)
    	admin_email="$2" 
        shift 2
        ;;
    --admin-password)
    	admin_password="$2" 
        shift 2
        ;;
    -h|--help)
        usage_exit
        ;;
    --)
        shift
        break
        ;;
    *)
        echo "Internal error!" 1>&2
        exit 1
        ;;
    esac
done

set -x
echo db_name=$db_name
echo db_user=$db_user
echo db_password=$db_password
echo site_host=$site_host
echo site_title=$site_title
echo admin_name=$admin_name
echo admin_email=$admin_email
echo admin_password=$admin_password

sudo setenforce 0
sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/sysconfig/selinux

sudo yum install -y epel-release
sudo yum install -y https://repo.varnish-cache.org/redhat/varnish-4.1.el7.rpm
sudo yum update -y
sudo yum install -y varnish mhash-devel

sudo yum -y install httpd php-mysql php php-gd php-mbstring php-xml mariadb mariadb-server curl unzip

sudo sed -i.orig 's/^;date.timezone =/date.timezone = Asia\/Tokyo/' /etc/php.ini

sudo sed -i.orig 's/^Listen 80/Listen 8080/;s/^#\(ServerName www.example.com:80\)/ServerName '$site_host':8080/' /etc/httpd/conf/httpd.conf
sudo systemctl start httpd
sudo systemctl enable httpd

sudo sed -i.orig 's/^VARNISH_LISTEN_PORT=6081/VARNISH_LISTEN_PORT=80/' /etc/varnish/varnish.params
sudo systemctl start varnish
sudo systemctl enable varnish
sudo systemctl start varnishncsa
sudo systemctl enable varnishncsa

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
create database $db_name;
grant all on $db_name.* to $db_user identified by '$db_password';
EOF

curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
chmod +x /usr/local/bin/wp

sudo /usr/local/bin/wp core download --path=/var/www/html/ --locale=ja
sudo /usr/local/bin/wp core config --path=/var/www/html/ --dbname="$db_name" --dbuser="$db_user" --dbpass="$db_password" --dbhost=localhost --locale=ja
sudo /usr/local/bin/wp core install --path=/var/www/html/ --url="http://$site_host" --title="$site_title" --admin_name="$admin_name" --admin_email="$admin_email" --admin_password="$admin_password"
sudo /usr/local/bin/wp plugin update --path=/var/www/html/ --all
sudo /usr/local/bin/wp plugin install wordpress-importer --path=/var/www/html/ --activate

curl -LO https://raw.github.com/jawordpressorg/theme-test-data-ja/master/wordpress-theme-test-date-ja.xml
sudo /usr/local/bin/wp import --path=/var/www/html/ --authors=create wordpress-theme-test-date-ja.xml
rm wordpress-theme-test-date-ja.xml

sudo chown -R apache: /var/www/html/*

sudo yum install -y python-virtualenv python-pip
virtualenv venv
source venv/bin/activate
pip install httpie

## setup varnish vmod build env
sudo yum install -y varnish-libs-devel varnish-debuginfo python-docutils \
                    autoconf automake libtool gcc make yum-utils rpm-build rpmdevtools
rpmdev-setuptree

## download, build and install vmod-example for varnish 4.1.x
curl -sL -o /home/vagrant/rpmbuild/SOURCES/libvmod-example.tar.gz https://github.com/varnish/libvmod-example/archive/4.1.tar.gz
tar xf /home/vagrant/rpmbuild/SOURCES/libvmod-example.tar.gz --strip-components=1 -C /home/vagrant/rpmbuild/SPECS/ libvmod-example-4.1/vmod-example.spec
sed -i.orig '/^%setup -n libvmod-example-trunk/s/trunk/4.1/
/^%build/a\
./autogen.sh
/^mv %{buildroot}\/usr\/share\/doc\/lib%{name} %{buildroot}\/usr\/share\/doc\/%{name}/a\
rm %{buildroot}/usr/lib64/varnish/vmods/libvmod_example.la
' /home/vagrant/rpmbuild/SPECS/vmod-example.spec
rpmbuild -bb /home/vagrant/rpmbuild/SPECS/vmod-example.spec
sudo rpm -i /home/vagrant/rpmbuild/RPMS/x86_64/vmod-example-*.rpm

# setup rust
sudo yum install -y git clang
curl -sfO https://raw.githubusercontent.com/brson/multirust/master/blastoff.sh
sh blastoff.sh --yes

git clone https://github.com/crabtw/rust-bindgen ~/rust-bindgen
(cd ~/rust-bindgen && cargo build --release)

git clone https://github.com/tkengo/highway.git ~/highway
(cd ~/highway && ./tools/build.sh && sudo make install)

mkdir -p ~/vmod-example-rs
(cd ~/vmod-example-rs && \
 ~/rust-bindgen/target/release/bindgen -l varnishapi -match vcl.h -o vcl.rs /usr/include/varnish/vcl.h && \
 ~/rust-bindgen/target/release/bindgen -l varnishapi -match vrt.h -o vrt.rs /usr/include/varnish/vrt.h && \
 ~/rust-bindgen/target/release/bindgen -I/usr/include/varnish -l varnishapi -match cache.h -o cache.rs \
   /usr/include/varnish/cache/cache.h && \
 ~/rust-bindgen/target/release/bindgen -I/usr/include/varnish -l varnishapi -match vcc_if.h -o vcc_if.rs \
   ~/rpmbuild/SOURCES/libvmod-example-4.1/src/vcc_if.h /usr/include/varnish/vrt.h
 )


