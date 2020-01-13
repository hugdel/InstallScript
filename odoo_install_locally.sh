#!/bin/bash
################################################################################
# Script for installing Odoo on Ubuntu 14.04, 15.04, 16.04 and 18.04 (could be used for other version too)
# Author: Yenthe Van Ginneken
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu 16.04 server. It can install multiple Odoo instances
# in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
# Make a new file:
# sudo nano odoo-install.sh
# Place this content in it and then make the file executable:
# sudo chmod +x odoo-install.sh
# Execute the script to install Odoo:
# ./odoo-install
################################################################################

. ./env_var.sh

OE_USER=$(whoami)
OE_HOME=$PWD
OE_HOME_EXT="${OE_HOME}/odoo"
# The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
# Set to true if you want to install it, false if you don't need it or have it already installed.
#INSTALL_WKHTMLTOPDF="True"
# Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
#OE_PORT="8069"
#OE_LONGPOLLING_PORT="8072"
# Choose the Odoo version which you want to install. For example: 12.0, 11.0, 10.0 or saas-18. When using 'master' the master version will be installed.
# IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 12.0
#OE_VERSION="stable_prod_12.0"
# set the superadmin password
#OE_SUPERADMIN="admin"
OE_CONFIG_FILE="${OE_HOME}/config.conf"
OE_CONFIG="${OE_USER}"
MINIMAL_ADDONS="False"
#INSTALL_NGINX="True"

echo -e "* Create server config file"

touch ${OE_CONFIG_FILE}
echo -e "* Creating server config file"
printf '[options] \n; This is the password that allows database operations:\n' > ${OE_CONFIG_FILE}
printf "admin_passwd = ${OE_SUPERADMIN}\n" >> ${OE_CONFIG_FILE}
printf "db_host = False\n" >> ${OE_CONFIG_FILE}
printf "db_port = False\n" >> ${OE_CONFIG_FILE}
printf "db_user = ${OE_USER}\n" >> ${OE_CONFIG_FILE}
printf "db_password = False\n" >> ${OE_CONFIG_FILE}
printf "xmlrpc_port = ${OE_PORT}\n" >> ${OE_CONFIG_FILE}
printf "longpolling_port = ${OE_LONGPOLLING_PORT}\n" >> ${OE_CONFIG_FILE}

printf "addons_path = ${OE_HOME_EXT}/addons,${OE_HOME}/addons/addons," >> ${OE_CONFIG_FILE}
printf "${OE_HOME}/addons/web," >> ${OE_CONFIG_FILE}
if [ $MINIMAL_ADDONS = "False" ]; then
    printf "${OE_HOME}/addons/scrummer," >> ${OE_CONFIG_FILE}
fi
printf "\n" >> ${OE_CONFIG_FILE}

printf "workers = 0\n" >> ${OE_CONFIG_FILE}
printf "max_cron_threads = 2\n" >> ${OE_CONFIG_FILE}

if [ ${INSTALL_NGINX} = "True" ]; then
    printf "xmlrpc_interface = 127.0.0.1\n" >> ${OE_CONFIG_FILE}
    printf "netrpc_interface = 127.0.0.1\n" >> ${OE_CONFIG_FILE}
    printf "proxy_mode = True\n" >> ${OE_CONFIG_FILE}
fi

echo -e "\n---- Create Virtual environment Python ----"
cd ${OE_HOME}
python3 -m venv venv
cd -

echo -e "\n---- Install python packages/requirements ----"
${OE_HOME}/venv/bin/pip3 install --upgrade pip
${OE_HOME}/venv/bin/pip3 install wheel
${OE_HOME}/venv/bin/pip3 install -r https://raw.githubusercontent.com/odoo/odoo/${OE_VERSION}/requirements.txt
${OE_HOME}/venv/bin/pip3 install phonenumbers

echo -e "\n---- Install Odoo with addons module ----"
git submodule update --init

echo -e "\n---- Add link dependency in site-packages of Python ----"
ln -fs ${OE_HOME_EXT}/odoo ${OE_HOME}/venv/lib/python3.7/site-packages/
ln -fs ${OE_HOME_EXT}/odoo ${OE_HOME}/venv/lib/python3.6/site-packages/
