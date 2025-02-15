#!/bin/bash
set -e

echo "🚀 Waiting for database..."
until mysqladmin ping -h"$MARIADB_HOST" --silent; do
    sleep 2
done

echo "✅ Database ready"

echo "Create database if not exists..."
mysql -h"$MARIADB_HOST" -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS $MARIADB_DB;"
echo " ✅ Database $MARIADB_DB created."

# Vérifier si WordPress est déjà installé
if ! wp core is-installed --allow-root --path=/var/www/html; then

    # check if the wp-config.php file does not exists
    if [ ! -f /var/www/html/wp-config.php ]; then
        echo "⚡ Download wordpress..."
        wp core download --allow-root

        echo "⚡ Create wp-config..."
        wp config create \
            --dbname="$MARIADB_DB" \
            --dbuser="$MARIADB_USER" \
            --dbpass="$MARIADB_PASSWORD" \
            --dbhost="$MARIADB_HOST" \
            --allow-root

        # avoid traeffik redirection loop
        if ! grep -q "FORCE_SSL_ADMIN" /var/www/html/wp-config.php; then
            echo "🔧 Ajout de la configuration HTTPS dans wp-config.php..."
            sed -i "2i define('FORCE_SSL_ADMIN', true);\nif (\$_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https') {\n  \$_SERVER['HTTPS'] = 'on';\n}" /var/www/html/wp-config.php
        else
            echo "✅ HTTPS configuration already set in wp-config.php"
        fi

        # allow direct installation and update of plugins/themes
        if ! grep -q "FS_METHOD" /var/www/html/wp-config.php; then
            echo "🔧 Enabling direct installation and update of plugins/themes"
            sed -i "2i define('FS_METHOD', 'direct');\ndefine('ALLOW_UNFILTERED_UPLOADS', true);\n" /var/www/html/wp-config.php
        else
            echo "✅ FS_METHOD already set in wp-config.php"
        fi
    fi



    echo "⚡ Install WordPress..."
    wp core install \
        --url="https://${WP_DOMAIN}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASS}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --allow-root

    echo "✅ WordPress installation successful."
else
    echo "🔄 Wordpress already installed, update urls"
    wp option update siteurl "https://${WP_DOMAIN}" --allow-root
    wp option update home "https://${WP_DOMAIN}" --allow-root
fi

# Install plugins
if [ -n "$WP_PLUGINS" ]; then
    echo "🔌 Plugins installation : $WP_PLUGINS"
    for plugin in $WP_PLUGINS; do
        wp plugin install $plugin --activate --allow-root
    done
fi

echo "🔧 chmod..."
find . -type d -exec chmod 755 {} \;
find . -type f -exec chmod 644 {} \;
chown -R www-data:www-data wp-content



echo "🚀 WordPress ready : https://${WP_DOMAIN}"

# Launch apache
exec apache2-foreground
