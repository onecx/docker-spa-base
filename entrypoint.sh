#!/bin/sh
echo "Starting..."

# Re-map environment variables
if [ -n "$ONECX_VAR_REMAP" ]; then
  echo "Re-mapping env vars: ${ONECX_VAR_REMAP}"
  OLD_IFS="$IFS"
  IFS=";"
  for pair in $ONECX_VAR_REMAP; do
    key=$(echo "$pair" | cut -d= -f1)
    val=$(echo "$pair" | cut -d= -f2)
    echo "Create var: '$key' from var '$val'"
    eval "export ${key}=\"\${$val}\""
  done
  IFS="$OLD_IFS"
  echo "Re-mapping finished"
fi

# Check custom env.json
if [ -f /tmp/env.json ]; then
  echo "Copying /tmp/env.json -> ${DIR_ASSETS}/env.json"
  cp /tmp/env.json "${DIR_ASSETS}/env.json"
else
  echo "No custom ${DIR_ASSETS}/env.json configuration"
fi

# Merge config env lists
config_env_names=$(echo "$CONFIG_ENV_LIST,$CONFIG_ENV_EXT_LIST" | tr ',' ' ')

# Update environment variables in env.json
if [ -f "${DIR_ASSETS}/env.json" ]; then
  for e in $(jq -r 'to_entries[]|.value' "${DIR_ASSETS}/env.json"); do
    case "$e" in
      '${'*'}')
        varname=$(echo "$e" | sed -e 's/^${//' -e 's/}$//')
        config_env_names="$config_env_names $varname"
        ;;
    esac
  done

  echo "Updating ${DIR_ASSETS}/env.json"
  for item in $config_env_names; do
    value=$(eval "printf '%s' \"\${$item}\"")
    if [ -n "$value" ]; then
      echo "Replace '$item' with '$value' in env.json"
      sed -i "s|\${$item}|$value|g" "${DIR_ASSETS}/env.json"
    fi
  done

  if [ "${ADDITIONAL_REPLACE:-false}" = "true" ]; then
    echo "Second update ${DIR_ASSETS}/env.json"
    for item in $config_env_names; do
      value=$(eval "printf '%s' \"\${$item}\"")
      if [ -n "$value" ]; then
        echo "Replace '$item' with '$value' in env.json"
        sed -i "s|\${$item}|$value|g" "${DIR_ASSETS}/env.json"
      fi
    done
  fi

  # Create INJECTED_ENV from env.json
  envJsonAsString=$(sed -E 's/\$\{.*\}/@UNDEFINED/' "${DIR_ASSETS}/env.json" | tr -d "\n")
  escaped_conf=$(printf '%s\n' "$envJsonAsString" | sed -e 's/[\/&]/\\&/g')
  injectScript="window[\"APP_CONFIG\"]=$escaped_conf;"
  export INJECTED_ENV="$injectScript"
  echo "Create and add 'INJECTED_ENV' to CONFIG_ENV list of variables"
  config_env_names="$config_env_names INJECTED_ENV"
else
  echo "Missing ${DIR_ASSETS}/env.json file to replace 'INJECTED_ENV'"
fi

# Update environment variables in nginx config files
for file in ${DIR_SERVER_BLOCKS}/*.conf ${DIR_LOCATION}/*.conf; do
  echo "Replacing '@@<var>' placeholders in file: $file"
  for item in $config_env_names; do
    value=$(eval "printf '%s' \"\${$item}\"")
    sed -i "s|@@$item|$value|g" "$file"
  done
done

echo "Done"

exec "$@"
