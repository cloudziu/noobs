#!/bin/bash
#Script created by Andrzej "Ferex" Szczepaniak
#Thanks for Jakub "Unknow" Mrugalski, Marcin "y0rune" Wozniak, Mariusz "maniek205" Kowalski and Paweł aka "./lemon.sh" for help
set -euo pipefail

apt update && apt install -y lsb-release ca-certificates apt-transport-https software-properties-common gnupg2

os_check=$(cat /etc/os-release | grep "^ID=")
if [[ $os_check == "ID=debian" ]] ;
then
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/sury-php.list
wget -qO - https://packages.sury.org/php/apt.gpg | apt-key add -
elif [[ $os_check == "ID=ubuntu" ]] ;
then
apt-add-repository ppa:ondrej/php -y
apt-add-repository ppa:ondrej/apache2 -y
fi

apt update

if [[ -f /usr/sbin/nginx ]]; then
    echo "Wybacz, ale nginxa nie wspieram obecnie :c"
    exit 0
fi
if [[ -f /usr/bin/php7.4 ]]; then
    php_version=7.4
    elif [[ -f /usr/bin/php8.0 || ! -f /usr/bin/php ]]; then
        php_version=8.0
    elif [[ -f /usr/bin/php7.3 ]]; then
    php_version=7.3
    elif [[ -f /usr/bin/php7.2 ]]; then
    php_version=7.2
    else
    echo "Nie masz wersji PHP którą ja wymagam, sprawdź to!"
    exit 0
fi

nextcloud_link=$(curl https://nextcloud.com/install/\#instructions-server \
	| grep -Eo 'https://.+\/releases\/.+\.zip"' | sed 's/"//g')

apt install -y apache2 libapache2-mod-fcgid php$php_version-fpm php$php_version-memcached php$php_version-memcache memcached libmemcached-tools openssl wget php$php_version-imagick php$php_version-xml php$php_version-intl php$php_version-dom php$php_version-mysqli php$php_version-sqlite3 php$php_version-gd php$php_version-mbstring php$php_version-common php$php_version-curl php$php_version-gd php$php_version-imap php$php_version-intl php$php_version-json php$php_version-mbstring php$php_version-mysql php$php_version-ssh2 php$php_version-xml php$php_version-zip php$php_version-apcu php$php_version-ldap php$php_version-apcu 
a2enmod dir env headers mime rewrite setenvif
a2dismod mpm_prefork php$php_version
a2enmod mpm_event proxy proxy_fcgi
a2enconf php$php_version-fpm
phpenmod apcu memcache
echo "apc.enable_cli=1" >> /etc/php/$php_version/cli/php.ini
echo "apc.enable_cli=1" >> /etc/php/$php_version/fpm/php.ini

crontab -l > /tmp/crontasks

if [[ -d "/storage" ]]; then
    if [[ -d "/storage/nextcloud/" ]]; then
        if [ "$(ls -A /storage/nextcloud)" ]; then
            mv /storage/nextcloud /storage/nextcloud-old
        fi
        rm -rf /storage/nextcloud
    fi
    cd /storage && wget "$nextcloud_link" -O nextcloud.zip
    cd /storage && unzip nextcloud.zip
    cd /storage && rm nextcloud.zip
    chown -R www-data:www-data /storage/nextcloud

aconf=$(cat <<EOF
Alias /nextcloud "/storage/nextcloud"
<Directory /storage/nextcloud>
  Options +FollowSymlinks
  AllowOverride All
  Require all granted
</Directory>
EOF
)

dirconf=$(cat <<EOF
<?php
$AUTOCONFIG = [
  "directory"     => "/storage/nextcloud/data",
];
EOF
)
echo "$dirconf" >> /storage/nextcloud/config/autoconfig.php

echo "*/5  *  *  *  * sudo -u www-data /usr/bin/php --define apc.enable_cli=1 -f /storage/nextcloud/cron.php" >> /tmp/crontasks
echo "$aconf" > /etc/apache2/sites-available/nextcloud.conf

else
cd /var/www/html && wget "$nextcloud_link" -O nextcloud.zip
cd /var/www/html && unzip nextcloud.zip
cd /var/www/html && rm nextcloud.zip
chown -R www-data:www-data /var/www/html

aconf=$(cat <<EOF
Alias /nextcloud "/var/www/html/nextcloud/"
<Directory /var/www/html/nextcloud>
  Options +FollowSymlinks
  AllowOverride All
</Directory>
EOF
)

dirconf=$(cat <<EOF
<?php
$AUTOCONFIG = [
  "directory"     => "/var/www/html/nextcloud/data",
];
EOF
)
echo "$dirconf" >> /var/www/html/nextcloud/config/autoconfig.php

echo "*/5  *  *  *  * sudo -u www-data /usr/bin/php --define apc.enable_cli=1 -f /var/www/html/nextcloud/cron.php" >> /tmp/crontasks
echo "$aconf" > /etc/apache2/sites-available/nextcloud.conf

fi

crontab /tmp/crontasks
rm /tmp/crontasks
a2ensite nextcloud
systemctl restart apache2