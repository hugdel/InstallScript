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
sudo su ${OE_USER} -c "git clone --branch ${BRANCH_GIT} ${REMOTE_URL_GIT} ${OE_HOME_ODOO}"
sudo cp ./env_var.sh ${OE_HOME_ODOO}
sudo chown -R ${OE_USER}:${OE_USER} ${OE_HOME_ODOO}/env_var.sh

LAST_PWD=$PWD
cd ${OE_HOME_ODOO}
sudo su ${OE_USER} -c "./odoo_install_locally.sh"
cd ${LAST_PWD}
#echo -e "\n* Updating server config file"
#sudo su ${OE_USER} -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /${OE_USER}/odoo/config.conf"

#--------------------------------------------------
# Adding ODOO as a daemon
#--------------------------------------------------
./odoo_install_daemon.sh

#--------------------------------------------------
# Install Nginx if needed
#--------------------------------------------------
if [ ${INSTALL_NGINX} = "True" ]; then
  echo -e "\n---- Installing and setting up Nginx ----"
  cat <<EOF > /tmp/nginx${OE_USER}
upstream odoo${OE_USER} {
  server 127.0.0.1:${OE_PORT};
}
upstream odoo${OE_USER}chat {
  server 127.0.0.1:${OE_LONGPOLLING_PORT};
}

server {
    listen 80;

    server_name ${WEBSITE_NAME};

    # Add Headers for odoo proxy mode
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";

    # odoo request log files
    access_log /var/log/nginx/${OE_USER}-access.log;
    error_log /var/log/nginx/${OE_USER}-error.log;

    # Increase proxy buffer size
    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;

    # Force timeouts if the backend dies
    proxy_next_upstream error timeout invalid_header http_500 http_502
    http_503;

    types {
       text/less less;
       text/scss scss;
    }

    # Enable data compression
    gzip on;
    gzip_min_length 1100;
    gzip_buffers 4 32k;
    gzip_types text/css text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
    gzip_vary on;
    client_header_buffer_size 4k;
    large_client_header_buffers 4 64k;
    client_max_body_size 1024M;

    location / {
       proxy_pass http://odoo${OE_USER};
       # by default, do not forward anything
       proxy_redirect off;
    }

    location /longpolling {
       proxy_pass http://odoo${OE_USER}chat;
    }

    # cache some static data in memory for 60mins.
    location ~ /[a-zA-Z0-9_-]*/static/ {
       proxy_cache_valid 200 302 60m;
       proxy_cache_valid 404 1m;
       proxy_buffering on;
       expires 864000;
       proxy_pass http://odoo${OE_USER};
    }
}
EOF

  sudo mv -f /tmp/nginx${OE_USER} /etc/nginx/sites-available/${WEBSITE_NAME}
  sudo ln -fs /etc/nginx/sites-available/${WEBSITE_NAME} /etc/nginx/sites-enabled/${WEBSITE_NAME}
  sudo rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default
  sudo systemctl restart nginx
  echo "Done! The Nginx server is up and running. Configuration can be found at /etc/nginx/sites-enabled/${WEBSITE_NAME}"
  echo "Run manually certbot : sudo certbot --nginx"
else
  echo "Nginx isn't installed due to choice of the user!"
fi
