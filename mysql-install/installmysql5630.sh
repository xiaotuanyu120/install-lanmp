#!/bin/bash

## env setting
BASEDIR=/usr/local/mysql
DATADIR=/data/mysql
PASSWORD=adminmysql
PIDFILE=/usr/local/mysql/mysql.pid

## mysql base packages installation
yum install cmake gcc gcc-c++ ncurses-devel -y
yum groupinstall base "Development Tools" -y

## create user
groupadd mysql
useradd -r -g mysql mysql

## unzip source package
[[ -d mysql ]] || mkdir mysql && rm -rf ./mysql && mkdir mysql
tar zxvf mysql-5.6.30.tar.gz -C mysql
mv ./mysql/mysql-5.6.30/* ./mysql/
cd mysql

## mysql install
cmake -DCMAKE_INSTALL_PREFIX=/usr/local/mysql -DMYSQL_DATADIR=/data/mysql -DMYSQL_USER=mysql -DMYSQL_TCP_PORT=3306 -DWITH_MYISAM_STORAGE_ENGINE=1 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DWITH_MEMORY_STORAGE_ENGINE=1 -DWITH_READLINE=1 -DENABLED_LOCAL_INFILE=1 -DWITH_EXTRA_CHARSETS=all -DDEFAULT_CHARSET=utf8 -DDEFAULT_COLLATION=utf8_general_ci
make
make install

mkdir -p $DATADIR
chown -R mysql:mysql $BASEDIR
chown -R mysql:mysql $DATADIR

## initialize database
cd $BASEDIR
./scripts/mysql_install_db --datadir=$DATADIR --user=mysql
cp ./support-files/mysql.server /etc/init.d/mysqld
rm -f /etc/my.cnf
cp ./support-files/my-default.cnf /etc/my.cnf
chmod 755 /etc/init.d/mysqld

sed -inr "s#^basedir=#basedir=$BASEDIR#g" /etc/init.d/mysqld
sed -inr "s#^datadir=#datadir=$DATADIR#g" /etc/init.d/mysqld
sed -inr "s#^pid_file=#pid_file=$PIDFILE#g" /etc/init.d/mysqld

sed -i "/\[mysqld\]/abasedir=$BASEDIR" /etc/my.cnf
sed -i "/\[mysqld\]/adatadir=$DATADIR" /etc/my.cnf
sed -i "/\[mysqld\]/apid_file=$PIDFILE" /etc/my.cnf

## service start and enable
chkconfig mysqld on
service mysqld start
$BASEDIR/bin/mysqladmin -u root password "$PASSWORD"
