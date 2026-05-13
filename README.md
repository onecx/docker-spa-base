# Base image for single page apps   

This image is basedon in NginX. 
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


## CORS Configuration

CORS headers allow your SPA to be accessed from trusted cross-origin domains (e.g., micro-frontend shell, portals).

> **Note:** The `cors-test/` folder in this repository is for local development and testing only. It is **not** included in the production Docker image.

### How CORS works in this image

CORS is configured using Nginx maps (`00-cors-map.conf`) that validate incoming `Origin` headers against an explicit allowlist. **Only matched origins receive CORS headers**; unmatched origins receive zero CORS headers.

### Configuration Variables

| Variable | Default | Purpose |
|---|---|---|
| `CORS_ENABLED` | `false` | Enable/disable CORS header emission |
| `CORS_ALLOW_ORIGIN` | `""` | Exact origin to allow (e.g., `https://shell.example.com`) |
| `CORS_ALLOW_REGEX_ORIGIN` | `^$` | Regex pattern for multiple origins (e.g., `^https://(shell\|portal)\.example\.com$`) |
| `CORS_ALLOW_CREDENTIALS` | `false` | Allow cookies/credentials in cross-origin requests (set true only with cookie-based auth) |
| `CORS_ALLOW_HEADERS` | `Authorization, Origin, X-Requested-With, Content-Type, Accept` | Allowed request headers |
| `CORS_ALLOW_METHODS` | `GET, POST, OPTIONS, HEAD` | Allowed HTTP methods |

### Usage Examples

**Option 1: Single Trusted Origin**
```dockerfile
FROM oci://ghcr.io/onecx/docker-spa-base:v1
ENV CORS_ENABLED true
ENV CORS_ALLOW_ORIGIN https://shell.example.com
```

**Option 2: Multiple Origins via Regex**
```dockerfile
FROM oci://ghcr.io/onecx/docker-spa-base:v1
ENV CORS_ENABLED true
ENV CORS_ALLOW_ORIGIN ""
ENV CORS_ALLOW_REGEX_ORIGIN ^https://(shell|portal)\.example\.com$
```

**Option 3: Public API (any origin, no credentials)**
```dockerfile
FROM oci://ghcr.io/onecx/docker-spa-base:v1
ENV CORS_ENABLED true
ENV CORS_ALLOW_ORIGIN "*"
ENV CORS_ALLOW_CREDENTIALS false
```

**Option 4: Credentials with Single Origin** (only if using cookie-based auth, not JWT)
```dockerfile
FROM oci://ghcx.io/onecx/docker-spa-base:v1
ENV CORS_ENABLED true
ENV CORS_ALLOW_ORIGIN https://shell.example.com
ENV CORS_ALLOW_CREDENTIALS true
```

### Do I need both `CORS_ALLOW_ORIGIN` and `CORS_ALLOW_REGEX_ORIGIN`?

**No.** Configure only one:

- **Use `CORS_ALLOW_ORIGIN`** for a single trusted origin
  - Keep `CORS_ALLOW_REGEX_ORIGIN=^$` (default)

- **Use `CORS_ALLOW_REGEX_ORIGIN`** for multiple origins
  - Keep `CORS_ALLOW_ORIGIN=""` (empty)

If both are set, the map checks them in order; whichever matches first wins.

### Testing CORS Configuration

The `cors-test/` folder contains helper files for local testing only and is **NOT** included in the production Docker image.

#### Quick test with curl (static assets)

Start container with mounted test assets:
```bash
DOCKER_API_VERSION=1.44 docker run --rm -p 8080:8080 \
  -v "$PWD/cors-test/assets:/usr/share/nginx/html" \
  -e CORS_ENABLED=true \
  -e APP_BASE_HREF=/ \
  -e CORS_ALLOW_ORIGIN=https://trusted.example \
  -e CORS_ALLOW_REGEX_ORIGIN=^$ \
  spa-base-cors-test
```

Test with untrusted origin (should have **NO** `Access-Control-Allow-Origin` header):
```bash
curl -v -H "Origin: https://evil.example" http://localhost:8080/test.woff2
```

Test with trusted origin (should have `Access-Control-Allow-Origin: https://trusted.example` header):
```bash
curl -v -H "Origin: https://trusted.example" http://localhost:8080/test.woff2
```

#### Full browser test with CORS test client

1. Build and start container with mounted assets:
```bash
DOCKER_API_VERSION=1.44 docker run --rm -p 8080:8080 \
  -v "$PWD/cors-test/assets:/usr/share/nginx/html" \
  -e CORS_ENABLED=true \
  -e APP_BASE_HREF=/ \
  -e CORS_ALLOW_ORIGIN="" \
  -e CORS_ALLOW_REGEX_ORIGIN='^https://(trusted\.example|shell\.example)$' \
  spa-base-cors-test
```

2. In another terminal, serve the test client:
```bash
cd cors-test/client
python3 -m http.server 9000
```

3. Open `http://localhost:9000` in your browser and click the test buttons to see real browser CORS behavior.

### Security Notes

- **Default is safe**: `CORS_ENABLED=false` means CORS headers are never sent
- **Never use `* + credentials`**: Combining `CORS_ALLOW_ORIGIN=*` with `CORS_ALLOW_CREDENTIALS=true` is a security vulnerability
- **JWT tokens are safer**: If you use JWT Bearer tokens (recommended), set `CORS_ALLOW_CREDENTIALS=false`; credentials in CORS are only needed for cookie-based auth
- **Prefer explicit allowlists**: Use exact origins or narrow regex patterns, not broad wildcards
