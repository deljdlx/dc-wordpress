FROM wordpress:latest

# Installer WP-CLI
RUN apt-get update && apt-get install -y less mariadb-client && \
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

RUN echo "memory_limit=512M" > /usr/local/etc/php/conf.d/memory_limit.ini

# Copier notre script d'initialisation
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Exécuter notre script, puis appeler le entrypoint de WordPress
ENTRYPOINT ["/bin/sh", "-c", "/entrypoint.sh && exec docker-entrypoint.sh apache2-foreground"]
