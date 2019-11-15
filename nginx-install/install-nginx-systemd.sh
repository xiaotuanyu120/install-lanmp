#!/usr/bin/env bash

set -e

# ENV
NGX_USER=www
NGX_VER=1.16.1
NGX_DIR=/usr/local/nginx
NGX_PID=${NGX_DIR}/logs/nginx.pid

WORKDIR=/usr/local/src

# INSTALL BASE SOFTWARE
yum install wget epel-release -y
yum install gcc gcc-c++ cmake ncurses-devel pcre-devel openssl openssl-devel -y

# CREATE USER
id ${NGX_USER} 2>&1 || {
	groupadd ${NGX_USER}
	useradd -r -s /sbin/nologin -g ${NGX_USER} ${NGX_USER}
}

# DOWNLOAD NGINX PACKAGE AND UNCOMPRESS IT
[ -d ${WORKDIR} ] || mkdir -p ${WORKDIR}
cd ${WORKDIR}

[ -f ${WORKDIR}/nginx.tar.gz ] && {
	mv ${WORKDIR}/nginx.tar.gz ${WORKDIR}/bak.nginx.tar.gz.`date +%Y%m%d-%H%M%S`
}
wget https://nginx.org/download/nginx-${NGX_VER}.tar.gz -O ${WORKDIR}/nginx.tar.gz

[ -d nginx-${NGX_VER} ] && {
	mv ${WORKDIR}/nginx-${NGX_VER} ${WORKDIR}/bak.nginx-${NGX_VER}.`date +%Y%m%d-%H%M%S`
}
tar zxf nginx.tar.gz

# COMPILE NGINX AND INSTALL IT
cd nginx-${NGX_VER}
./configure --user=${NGX_USER} --group=${NGX_USER} \
    --prefix=${NGX_DIR} --pid-path=${NGX_PID} \
    --with-http_stub_status_module \
    --with-http_ssl_module --with-pcre \
    --with-http_realip_module
make
make install
ln -s ${NGX_DIR}/sbin/nginx /usr/sbin/nginx
chown -R ${NGX_USER}.${NGX_USER} ${NGX_DIR}
setcap 'cap_net_bind_service=+ep' ${NGX_DIR}/sbin/nginx

# PREPARE SERVICE FILES
cat << EOF > /usr/lib/systemd/system/nginx.service
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
User=${NGX_USER}
Group=${NGX_USER}
PIDFile=${NGX_PID}
ExecStartPre=${NGX_DIR}/sbin/nginx -t
ExecStart=${NGX_DIR}/sbin/nginx
ExecReload=${NGX_DIR}/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true
LimitNOFILE=65535
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# ENABLE AND START NGINX
systemctl daemon-reload
systemctl enable nginx
systemctl start nginx