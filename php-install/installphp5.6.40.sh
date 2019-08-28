set -e

## VARIABLE SETTING
PHPDIR=/usr/local/php5.6.40
CONFDIR=$PHPDIR/etc
PHPFPM_USER=www
PHPFPM_MODE=static

## USER CREATE
id ${PHPFPM_USER} >/dev/null 2>&1 || useradd -r -s /sbin/nologin ${PHPFPM_USER} && echo "${PHPFPM_USER} already exist!!"

## BASE PACKAGE INSTALLATION
yum install gcc gcc-c++ cmake ncurses-devel epel-release -y
#yum groupinstall base "Development Tools" -y
yum install libxml2-devel libcurl-devel libjpeg-turbo-devel libpng-devel freetype-devel php-mcrypt libmcrypt-devel libevent-devel openssl-devel libxslt-devel -y

## LIB PREPARE
[[ -L /usr/lib/libjpeg.so ]] || ln -s /usr/lib64/libjpeg.so /usr/lib/libjpeg.so
[[ -L /usr/lib/libpng.so ]] || ln -s /usr/lib64/libpng.so /usr/lib/libpng.so

## TARBALL INSTALL PHP
[[ -d php-5.6.40 ]] && mv php-5.6.40 bak.php-5.6.40.`date +%Y%m%d-%H%M%S`
[[ -f php-5.6.40.tar.gz ]] || wget https://www.php.net/distributions/php-5.6.40.tar.gz
tar zxvf php-5.6.40.tar.gz
cd php-5.6.40
./configure --prefix=$PHPDIR --with-config-file-path=$CONFDIR \
    --with-config-file-scan-dir=$CONFDIR/php.d \
    --enable-fpm --with-fpm-user=${PHPFPM_USER} --with-fpm-group=${PHPFPM_USER} \
    --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-mysql=mysqlnd --with-libxml-dir \
    --with-gd --enable-gd-native-ttf --with-jpeg-dir --with-png-dir --with-freetype-dir --with-iconv-dir --with-zlib-dir \
    --with-libxml-dir --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-exif \
    --disable-debug --enable-sysvsem --enable-inline-optimization --enable-mbregex \
    --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-ftp --with-xsl \
    --with-mcrypt --enable-soap --enable-gd-native-ttf --enable-ftp --enable-mbstring --enable-exif \
    --disable-ipv6 --with-curl --with-openssl \
    --with-gettext --enable-zip
make
make install

## INIT CONFIG FILE AND DAEMON FILE PREPARE
[[ -d $CONFDIR ]] || mkdir $CONFDIR && echo "$CONFDIR already exist"
cp php.ini-production $CONFDIR/php.ini
cp $CONFDIR/php-fpm.conf.default $CONFDIR/php-fpm.conf
cp ../php-fpm.service /usr/lib/systemd/system/
chmod 644 /usr/lib/systemd/system/php-fpm.service

## PHP-FPM COINFGURATION
### config: global
sed -inr 's#.*pid.*php-fpm.pid.*#pid = run/php-fpm.pid#g' $CONFDIR/php-fpm.conf
sed -inr 's#.*;error_log = .*#error_log = log/php-fpm.error.log#g' $CONFDIR/php-fpm.conf
sed -inr 's#.*;emergency_restart_threshold = 0.*#emergency_restart_threshold = 30#g' $CONFDIR/php-fpm.conf
sed -inr 's#.*;emergency_restart_interval = 0.*#emergency_restart_interval = 60s#g' $CONFDIR/php-fpm.conf
sed -inr 's#.*;daemonize =.*#daemonize = yes#g' $CONFDIR/php-fpm.conf
### config: pool
sed -inr 's#.*listen =.*#listen = /tmp/php-cgi.sock#g' $CONFDIR/php-fpm.conf
sed -inr "s#.*;listen.owner =.*#listen.owner = ${PHPFPM_USER}#g" $CONFDIR/php-fpm.conf
sed -inr "s#.*;listen.group =.*#listen.group = ${PHPFPM_USER}#g" $CONFDIR/php-fpm.conf
sed -inr 's#.*;listen.mode =.*#listen.mode = 0660#g' $CONFDIR/php-fpm.conf
sed -inr "s#.*user =.*#user = ${PHPFPM_USER}#g" $CONFDIR/php-fpm.conf
sed -inr "s#.*group =.*#group = ${PHPFPM_USER}#g" $CONFDIR/php-fpm.conf
sed -inr "s#.*pm =.*#pm = ${PHPFPM_MODE}#g" $CONFDIR/php-fpm.conf
sed -inr 's#.*pm.max_children =.*#pm.max_children = 80#g' $CONFDIR/php-fpm.conf
sed -inr 's#.*pm.start_servers =.*#pm.start_servers = 60#g' $CONFDIR/php-fpm.conf
sed -inr 's#.*pm.min_spare_servers =.*#pm.min_spare_servers = 50#g' $CONFDIR/php-fpm.conf
sed -inr 's#.*pm.max_spare_servers =.*#pm.max_spare_servers = 80#g' $CONFDIR/php-fpm.conf
sed -inr 's#.*;pm.process_idle_timeout =.*#pm.process_idle_timeout = 10s;#g' $CONFDIR/php-fpm.conf
sed -inr 's#.*;pm.max_requests =.*#pm.max_requests = 500#g' $CONFDIR/php-fpm.conf
sed -inr 's#.*;catch_workers_output =.*#catch_workers_output = yes#g' $CONFDIR/php-fpm.conf
sed -inr 's#.*;access.log =.*#access.log = var/log/$pool.access.log#g' $CONFDIR/php-fpm.conf
sed -inr 's#.*;slowlog =.*#slowlog = var/log/$pool.log.slow#g' $CONFDIR/php-fpm.conf
sed -inr 's#.*;request_slowlog_timeout =.*#request_slowlog_timeout = 1s#g' $CONFDIR/php-fpm.conf
## PHP CONFIGURATION
sed -inr 's#.*disable_functions =.*#disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server,fsocket,popen#g' $CONFDIR/php.ini
sed -inr 's#.*expose_php =.*#expose_php = Off#g' $CONFDIR/php.ini
sed -inr 's#.*;date.timezone =.*#date.timezone = Asia/Shanghai#g' $CONFDIR/php.ini

## SERVICE ENABLE AND START
systemctl daemon-reload
systemctl enable php-fpm
