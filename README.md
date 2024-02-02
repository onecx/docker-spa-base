# Base image for single page apps   

This image is basedon in NginX(Bitnami variant). 
It exposes NginX http server on port 8080, provides a simple static endpoint for healthcheck at `/healthcheck` url. All images and fonts will have cache headers set to 1 month, as well as webpack hashed assets(js and css bundles) as they have hashes included in their names. 

# Usage

```
FROM oci://ghcr.io/onecx/docker-spa-base:v1
# Copy applicaiton build
COPY --from=build --chown=101:0 /ng-app/dist $DIR_HTML
# Define application nginx locations
COPY nginx/locations.conf $DIR_LOCATION/locations.conf
# Define list of application environments
ENV CONFIG_ENV BFF_URL APP_BASE_HREF
# Application environments default values
ENV BFF_URL http://my-bff:8080/
ENV APP_BASE_HREF /my-ui/
```

# Configuration

Structure:
* `default.conf` - nginx server configuration
* `locations/common.conf` - common locations for the server like errors 400, 404, ...
* `locations/base.conf` - base locations for the application.
* `entrypoint.sh` - default entrypoint script

Application needs to define `CONFIG_ENV_LIST` environment variables in the `Dockerfile` as list of environment variable names to replace in configuration files. Default value:
```
ENV CONFIG_ENV_LIST BFF_URL APP_BASE_HREF APP_ID CORS_ENABLED
```
By default, the static html assets will be served under root path `/`, but this can be configured by setting an env var `APP_BASE_HREF`. If you set it, it should start and end with a forward slash e.g. `/my-app/`.


## Adding CORS headers 

In case your SPA resources need to be access from another host (such as micro frontend shell) you need to add CORS headers to the corresponding location blocks. You can do it for the built-in blocks by settinng env var `CORS_ENABLED` to truthy value e.g. `CORS_ENABLED=true`. See `locations/base.conf` for more info.
