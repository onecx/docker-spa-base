FROM nginxinc/nginx-unprivileged:1.29.0@sha256:502f1c37b8f59632f42cc615a5bb4709bb8e1cbc0e728118496361dfbc4302af

ENV DIR_NGINX /etc/nginx
ENV DIR_SERVER_BLOCKS ${DIR_NGINX}/conf.d
ENV DIR_LOCATION ${DIR_SERVER_BLOCKS}/locations
ENV DIR_HTML /usr/share/nginx/html
ENV DIR_ASSETS ${DIR_HTML}/assets

ENV CORS_ENABLED false

USER root
RUN apt-get update -y && \
    apt-get install -y jq && \
    rm -rf ${DIR_HTML}/* && \
    mkdir -p ${DIR_LOCATION} && \
    # chown 1001 -R ${DIR_SERVER_BLOCKS} && \
    chmod 775 -R ${DIR_SERVER_BLOCKS} && \
    chmod 775 -R ${DIR_LOCATION}

# setup entry point
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

# nginx default configuration
COPY locations/*.conf ${DIR_LOCATION}/
COPY default.conf ${DIR_SERVER_BLOCKS}

# default list of environment variable names
ENV CONFIG_ENV_LIST BFF_URL,APP_BASE_HREF,CORS_ENABLED,APP_VERSION,APP_ID,PRODUCT_NAME,TKIT_PORTAL_URL
# RUN chown -R 1001:1001 /var && mkdir -p /var/run && touch /var/run/nginx.pid && chmod 775 -R /var/run/nginx.pid

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]

# Default build user root, runtime user 1001
# USER 1001
