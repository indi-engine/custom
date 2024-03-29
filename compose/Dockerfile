FROM debian:11-slim

## <Misc> ##
RUN apt-get update && apt-get install -fy mc curl wget lsb-release
## </Misc> ##

## <User> ##
ENV user www-data
RUN usermod -s /bin/bash $user
## </User> ##

## <Apache> ##
RUN apt-get install -y apache2
WORKDIR /etc/apache2
RUN echo "ServerName indi-engine"      >> apache2.conf  && \
    echo "<Directory /var/www/html>"   >> apache2.conf  && \
    echo "  AllowOverride All"         >> apache2.conf  && \
    echo "</Directory>"                >> apache2.conf  && \
    cp mods-available/rewrite.load        mods-enabled/ && \
    cp mods-available/headers.load        mods-enabled/ && \
    cp mods-available/proxy.load          mods-enabled/ && \
    cp mods-available/proxy_http.load     mods-enabled/ && \
    cp mods-available/proxy_wstunnel.load mods-enabled/ && \
    echo "export HOME=/var/www"        >> envvars
WORKDIR /var/www/html
## </Apache> ##

## <PHP> ##
RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list && \
    apt update && apt -y install php7.4 php7.4-mysql php7.4-curl php7.4-mbstring php7.4-dom php7.4-gd php7.4-zip php7.4-imagick && \
    update-alternatives --set php /usr/bin/php7.4
## </PHP> ##

## <JRE> ##
RUN apt-get install -y default-jre
## </JRE> ##

## <GitHub CLI>
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt update && apt install gh -y
## </GitHub CLI>

## <Composer> ##
RUN apt -y install composer
COPY composer.json composer.lock .
RUN chown -R $user:$user ..
USER $user
RUN composer install && \
  sed -i 's~\tpushurl\s*=\s*.*~~' vendor/indi-engine/system/.git/config && \
  sed -i 's~\tpushurl\s*=\s*.*~~' vendor/indi-engine/client/.git/config && \
  mv vendor ../vendor && \
  mv .idea  ../.idea
### </Composer> ##

## <IndiEngine> ##
USER root
COPY . .
RUN chown -R $user .
## </IndiEngine> ##

ENTRYPOINT ["/var/www/html/docker-entrypoint.sh"]
EXPOSE 80