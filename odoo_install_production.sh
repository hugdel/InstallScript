#!/bin/bash
################################################################################
# Script for installing Odoo on Ubuntu 14.04, 15.04, 16.04 and 18.04 (could be used for other version too)
# Author: Yenthe Van Ginneken
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu 16.04 server. It can install multiple Odoo instances
# in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
################################################################################

. ./env_var.sh

#OE_USER="odoo"
#OE_HOME="/${OE_USER}"
#OE_HOME_EXT="/${OE_USER}/odoo/odoo"
## The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
## Set to true if you want to install it, false if you don't need it or have it already installed.
#INSTALL_WKHTMLTOPDF="True"
## Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
#OE_PORT="8069"
#OE_LONGPOLLING_PORT="8072"
## set the superadmin password
#OE_SUPERADMIN="admin"
#OE_CONFIG="${OE_USER}"

./odoo_install_debian_dependancy.sh

echo -e "\n---- Create ODOO system user ----"
sudo adduser --system --quiet --shell=/bin/bash --home=/${OE_USER} --gecos 'ODOO' --group ${OE_USER}
#The user should also be added to the sudo'ers group.
sudo adduser ${OE_USER} sudo

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s ${OE_USER}" 2> /dev/null || true

#echo -e "\n---- Create Log directory ----"
#sudo mkdir /var/log/${OE_USER}
#sudo chown ${OE_USER}:${OE_USER} /var/log/${OE_USER}

echo -e "\n---- Setting permissions on home folder ----"
sudo mkdir -p ${OE_HOME}
sudo chown -R ${OE_USER}:${OE_USER} ${OE_HOME}

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Clone this installation  ===="
REMOTE_URL_GIT=`git remote get-url origin`
BRANCH_GIT=`git rev-parse --abbrev-ref HEAD`
sudo su ${OE_USER} -c "git clone --branch ${BRANCH_GIT} ${REMOTE_URL_GIT} ${OE_HOME}"
sudo cp ./env_var.sh ${OE_HOME}
sudo chown -R ${OE_USER}:${OE_USER} ${OE_HOME}/env_var.sh

LAST_PWD=$PWD
cd ${OE_HOME}
sudo su ${OE_USER} -c "./odoo_install_locally.sh"
cd ${LAST_PWD}
#echo -e "\n* Updating server config file"
#sudo su ${OE_USER} -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /${OE_USER}/odoo/config.conf"

#--------------------------------------------------
# Adding ODOO as a daemon
#--------------------------------------------------
./odoo_install_daemon.sh
