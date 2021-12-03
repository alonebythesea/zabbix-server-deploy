#!/bin/bash

###############################################################
#		DB install and config			      #
###############################################################

PASS='supasecurepa55wd'

sudo yum install mariadb mariadb-server -y
sudo /usr/bin/mysql_install_db --user=mysql
sudo systemctl start mariadb

mysql -uroot -Bse "create database zabbix character set utf8 collate utf8_bin;"
mysql -uroot -Bse "grant all privileges on zabbix.* to 'zabbix'@'localhost' identified by '${PASS}';" 

###############################################################
#		zabbix install and config		      #
###############################################################

sudo yum install -y https://repo.zabbix.com/zabbix/5.0/rhel/7/x86_64/zabbix-release-5.0-1.el7.noarch.rpm
sudo yum install -y zabbix-server-mysql zabbix-agent 

#Import db schemas and configs
zcat /usr/share/doc/zabbix-server-mysql-*/create.sql.gz |  mysql -uzabbix -p${PASS} zabbix

sudo yum --enablerepo=base -y install yum-utils
sudo yum-config-manager --enable zabbix-frontend
sudo yum -y install centos-release-scl
sudo yum -y install zabbix-web-mysql-scl zabbix-apache-conf-scl

sudo cat<<EOF>>/etc/zabbix/zabbix_server.conf
LogFile=/var/log/zabbix/zabbix_server.log
LogFileSize=0
PidFile=/var/run/zabbix/zabbix_server.pid
SocketDir=/var/run/zabbix
SNMPTrapperFile=/var/log/snmptrap/snmptrap.log
Timeout=4
AlertScriptsPath=/usr/lib/zabbix/alertscripts
ExternalScripts=/usr/lib/zabbix/externalscripts
LogSlowQueries=3000
DBPort=3306
DBHost=localhost
DBName=zabbix
DBUser=zabbix
DBPassword=${PASS}
EOF
sudo echo -e "\nphp_value[date.timezone] = Europe/Minsk" >> /etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf
sudo cat<<EOF>/etc/zabbix/web/zabbix.conf.php
<?php
\$DB['TYPE']                     = 'MYSQL';
\$DB['SERVER']                   = 'localhost';
\$DB['PORT']                     = '3306';
\$DB['DATABASE']                 = 'zabbix';
\$DB['USER']                     = 'zabbix';
\$DB['PASSWORD']                 = '${PASS}';
\$DB['SCHEMA']                   = '';
\$DB['ENCRYPTION']               = false;
\$DB['KEY_FILE']                 = '';
\$DB['CERT_FILE']                = '';
\$DB['CA_FILE']                  = '';
\$DB['VERIFY_HOST']              = false;
\$DB['CIPHER_LIST']              = '';
\$DB['DOUBLE_IEEE754']           = true;
\$ZBX_SERVER                     = 'localhost';
\$ZBX_SERVER_PORT                = '10051';
\$ZBX_SERVER_NAME                = 'Zabbix Server';
\$IMAGE_FORMAT_DEFAULT           = IMAGE_FORMAT_PNG;
EOF

sudo systemctl restart zabbix-server zabbix-agent httpd rh-php72-php-fpm
sudo systemctl enable zabbix-server zabbix-agent httpd rh-php72-php-fpm
