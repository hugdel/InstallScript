#!/bin/bash
################################################################################
# Script for installing Odoo on Ubuntu 14.04, 15.04, 16.04 and 18.04 (could be used for other version too)
# Author: Yenthe Van Ginneken
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu 16.04 server. It can install multiple Odoo instances
# in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
################################################################################

OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/odoo/odoo"
# The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
# Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"
# Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
# set the superadmin password
OE_SUPERADMIN="admin"
OE_CONFIG="${OE_USER}"

./odoo_install_debian_dependancy.sh

echo -e "\n---- Create ODOO system user ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
#The user should also be added to the sudo'ers group.
sudo adduser $OE_USER sudo

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

echo -e "\n---- Create Log directory ----"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

echo -e "\n---- Setting permissions on home folder ----"
sudo mkdir -p $OE_HOME
sudo chown -R $OE_USER:$OE_USER $OE_HOME

#--------------------------------------------------
# Adding ODOO as a deamon (initscript)
#--------------------------------------------------
if [ ! -f /tmp/$OE_CONFIG ]; then
    echo -e "\n* Create init file"
cat <<EOF > /tmp/$OE_CONFIG
#!/bin/sh
### BEGIN INIT INFO
# Provides: $OE_CONFIG
# Required-Start: \$remote_fs \$syslog
# Required-Stop: \$remote_fs \$syslog
# Should-Start: \$network
# Should-Stop: \$network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Enterprise Business Applications
# Description: ODOO Business Applications
### END INIT INFO
PATH=/bin:/sbin:/usr/bin
DAEMON=$OE_HOME/odoo/venv/bin/python3
NAME=$OE_CONFIG
DESC=$OE_CONFIG
# Specify the user name (Default: odoo).
USER=$OE_USER
# Specify an alternate config file (Default: /etc/odoo-server.conf).
CONFIGFILE="${OE_HOME}/odoo/config.conf"
# pidfile
PIDFILE=/var/run/\${NAME}.pid
# Additional options that are passed to the Daemon.
DAEMON_OPTS="$OE_HOME_EXT/odoo-bin -c \$CONFIGFILE"
[ -x \$DAEMON ] || exit 0
[ -f \$CONFIGFILE ] || exit 0
checkpid() {
[ -f \$PIDFILE ] || return 1
pid=\`cat \$PIDFILE\`
[ -d /proc/\$pid ] && return 0
return 1
}
case "\${1}" in
start)
echo -n "Starting \${DESC}: "
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
stop)
echo -n "Stopping \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
echo "\${NAME}."
;;
restart|force-reload)
echo -n "Restarting \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
sleep 1
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
*)
N=/etc/init.d/\$NAME
echo "Usage: \$NAME {start|stop|restart|force-reload}" >&2
exit 1
;;
esac
exit 0
EOF

    echo -e "* Security Init File"
    sudo mv /tmp/$OE_CONFIG /etc/init.d/$OE_CONFIG
    sudo chmod 755 /etc/init.d/$OE_CONFIG
    sudo chown root: /etc/init.d/$OE_CONFIG

    echo -e "* Start ODOO on Startup"
    sudo update-rc.d $OE_CONFIG defaults

    echo -e "* Starting Odoo Service"
    sudo su root -c "/etc/init.d/$OE_CONFIG start"
fi
echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $OE_PORT"
echo "User service: $OE_USER"
echo "User PostgreSQL: $OE_USER"
echo "Code location: $OE_USER"
echo "Addons folder: $OE_USER/$OE_CONFIG/addons/"
echo "Start Odoo service: sudo service $OE_CONFIG start"
echo "Stop Odoo service: sudo service $OE_CONFIG stop"
echo "Restart Odoo service: sudo service $OE_CONFIG restart"
echo "-----------------------------------------------------------"

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Clone this installation  ===="
REMOTE_URL_GIT=`git remote get-url origin`
BRANCH_GIT=`git rev-parse --abbrev-ref HEAD`
sudo su ${OE_USER} -c "git clone --branch ${BRANCH_GIT} ${REMOTE_URL_GIT} ${OE_HOME}/odoo"

cd ${OE_HOME}/odoo
sudo su ${OE_USER} -c "./odoo_install_locally.sh"

echo -e "\n* Updating server config file"
sudo su ${OE_USER} -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /${OE_USER}/odoo/config.conf"

sudo su root -c "/etc/init.d/${OE_CONFIG} restart"
