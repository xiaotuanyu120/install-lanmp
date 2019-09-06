set -e

## VARIABLE SETTING
WEB_USER=www
HTTPDVER=2.4.41
APRVER=1.7.0
EXPVER=2.2.7
APUVER=1.6.1
PCREVER=8.43
PHPVER=5.6.40

HTTPDDIR=/usr/local/httpd-${HTTPDVER}
APRDIR=/usr/local/apr-${APRVER}
EXPDIR=/usr/local/expat-${EXPVER}
APUDIR=/usr/local/apr-util-${APUVER}
PCREDIR=/usr/local/pcre-${PCREVER}
PHPDIR=/usr/local/php-${PHPVER}
INSTALL_DIR=/usr/local/src

### choose mpm mode, more info check https://httpd.apache.org/docs/2.4/en/mpm.html
### avaliable content: event, worker, prefork
HTTPD_MPM_MODE=event

### determine install php module or not
### avaliable content: on, off
WITH_PHP=on

## BASE PACKAGES INSTALLATION
yum install epel-release -y
yum install gcc gcc-c++ zlib zlib-devel lynx -y
yum install wget -y

## USER CREATE
id ${WEB_USER} >/dev/null 2>&1 || useradd -r -s /sbin/nologin ${WEB_USER} && echo "${WEB_USER} already exist!!"

## GO TO INSTALL_DIR
cd ${INSTALL_DIR}

## APR INSTALLATION
[[ -f apr-${APRVER}.tar.gz ]] || wget http://mirror.rise.ph/apache//apr/apr-${APRVER}.tar.gz
[[ -d apr-${APRVER} ]] && mv apr-${APRVER} bak.apr-${APRVER}.`date +%Y%m%d-%H%M%S`
tar zxf apr-${APRVER}.tar.gz
cd apr-${APRVER}
./configure --prefix=${APRDIR}
make
make install
cd ${INSTALL_DIR}

## EXPAT INSTALLATION
[[ -f expat-${EXPVER}.tar.gz ]] || wget https://github.com/libexpat/libexpat/releases/download/R_2_2_7/expat-${EXPVER}.tar.gz
[[ -d expat-${EXPVER} ]] && mv expat-${EXPVER} bak.expat-${EXPVER}.`date +%Y%m%d-%H%M%S`
tar zxf expat-${EXPVER}.tar.gz
cd expat-${EXPVER}
./configure --prefix=${EXPDIR}
make
make install
cd ${INSTALL_DIR}

## APR-UTIL INSTALLATION
[[ -f apr-util-${APUVER}.tar.gz ]] || wget http://mirror.rise.ph/apache//apr/apr-util-${APUVER}.tar.gz
[[ -d apr-util-${APUVER} ]] && mv apr-util-${APUVER} bak.apr-util-${APUVER}.`date +%Y%m%d-%H%M%S`
tar zxf apr-util-${APUVER}.tar.gz
cd apr-util-${APUVER}
./configure --prefix=${APUDIR} --with-apr=${APRDIR} --with-expat=${EXPDIR}
make
make install
cd ${INSTALL_DIR}

## PCRE INSTALLATION
[[ -f pcre-${PCREVER}.tar.gz ]] || wget https://ftp.pcre.org/pub/pcre/pcre-${PCREVER}.tar.gz
[[ -d pcre-${PCREVER} ]] && mv pcre-${PCREVER} bak.pcre-${PCREVER}.`date +%Y%m%d-%H%M%S`
tar zxf pcre-${PCREVER}.tar.gz
cd pcre-${PCREVER}
./configure --prefix=${PCREDIR}
make
make install
cd ${INSTALL_DIR}

## HTTPD INSTALLATION
[[ -f httpd-${HTTPDVER}.tar.gz ]] || wget http://mirror.rise.ph/apache//httpd/httpd-${HTTPDVER}.tar.gz
[[ -d httpd-${HTTPDVER} ]] && mv httpd-${HTTPDVER} bak.httpd-${HTTPDVER}.`date +%Y%m%d-%H%M%S`
tar zxf httpd-${HTTPDVER}.tar.gz
cd httpd-${HTTPDVER}
./configure --prefix=${HTTPDDIR} --with-apr=${APRDIR} \
  --with-apr-util=${APUDIR} --with-pcre=${PCREDIR} --with-expat=${EXPDIR}\
  --enable-rewrite --enable-so --enable-headers --enable-expires \
  --with-mpm=${HTTPD_MPM_MODE} --enable-modules=most --enable-deflate
make
make install
cd ${INSTALL_DIR}

# WITH_PHP INSTALLATION
if [ ${WITH_PHP} = "on" ]
then
  [[ -d php-${PHPVER} ]] && mv php-${PHPVER} bak.php-${PHPVER}.`date +%Y%m%d-%H%M%S`
  [[ -f php-${PHPVER}.tar.gz ]] || wget https://www.php.net/distributions/php-${PHPVER}.tar.gz
  tar zxvf php-${PHPVER}.tar.gz
  cd php-${PHPVER}
  # apxs
  ./configure --prefix=${PHPDIR} --with-apxs2=${HTTPDDIR}/bin/apxs --with-mysql
  make
  make install
  cd ${INSTALL_DIR}
fi

## CREATE HTTPD-VIRTUALHOST-DIR
[[ -d ${HTTPDDIR}/conf/site-enabled ]] || mkdir ${HTTPDDIR}/conf/site-enabled

## HTTPD PROGRAM CONFIG
sed -nri "s#.*User daemon.*#User ${WEB_USER}#g" ${HTTPDDIR}/conf/httpd.conf
sed -nri "s#.*Group daemon.*#Group ${WEB_USER}#g" ${HTTPDDIR}/conf/httpd.conf
sed -nri "/<IfModule ssl_module>/aListen 443" ${HTTPDDIR}/conf/httpd.conf
sed -nri "/<IfModule mime_module>/a\ \ \ \ AddType application/x-httpd-php .php" ${HTTPDDIR}/conf/httpd.conf

sed -nri "s#^\#Include conf/extra/httpd-mpm.conf.*#Include conf/extra/httpd-mpm.conf#g" ${HTTPDDIR}/conf/httpd.conf
## MODULE CONFIG
sed -nri "s#^\#LoadModule ssl_module modules/mod_ssl.so.*#LoadModule ssl_module modules/mod_ssl.so#g" ${HTTPDDIR}/conf/httpd.conf
sed -nri "/Include conf\/extra\/httpd-vhosts.conf/aInclude conf\/site-enabled\/*.conf" ${HTTPDDIR}/conf/httpd.conf

## HTTPD SYSTEMD UNIT FILE PREPARE
echo "[Unit]
Description=Apache Web Server
After=network.target

[Service]
Type=forking
PIDFile=${HTTPDDIR}/logs/httpd.pid
ExecStart=${HTTPDDIR}/bin/apachectl start
ExecStop=${HTTPDDIR}/bin/apachectl graceful-stop
ExecReload=${HTTPDDIR}/bin/apachectl graceful
PrivateTmp=true
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target" > /usr/lib/systemd/system/httpd.service


## COPY DAEMON FILE
cp $HTTPDDIR/bin/apachectl /etc/init.d/httpd
chmod a+x /etc/init.d/httpd