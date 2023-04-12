echo "Starting..."
if [[ -v ONECX_VAR_REMAP ]]; then
  echo "Re-mapping env vars: ${ONECX_VAR_REMAP}"
  IFS=";"
  for pair in ${ONECX_VAR_REMAP}; do
    key=${pair%=*}
    val=${pair#*=}
    echo "Create var: '$key' from var '$val'"
    export "${key}"="${!val}"
  done
  echo "Re-mapping finished"
fi 
unset IFS


# Check custom env.json
if [ -f /tmp/env.json ]; then
  echo "Copying /tmp/env.json -> ${DIR_ASSETS}/env.json"
  cp /tmp/env.json ${DIR_ASSETS}/env.json
else
  echo "No custom ${DIR_ASSETS}/env.json configuration"
fi

IFS=, read -ra config_env_names <<< "$CONFIG_ENV_LIST"

# Update environment variables in env.json
if [ -f ${DIR_ASSETS}/env.json ]; then
  
  for e in $(jq -r 'to_entries[]|.value' ${DIR_ASSETS}/env.json); do
    if [[ $e == \$\{*\} ]]; then
      e=${e:2}
      config_env_names=$config_env_names" "${e::-1}
    fi
  done

  echo "Updating ${DIR_ASSETS}/env.json"
  for item in $config_env_names; do
    value=$(printf '%s\n' "${!item}")
    if [[ ! -z "$value" ]]; then
      echo "Replace '$item' with '$value' in env.json"
      sed -i "s|\${$item}|$value|g" ${DIR_ASSETS}/env.json
    fi
  done

  # Create INJECTED_ENV from env.json
  envJsonAsString=$(sed -E 's/\$\{.*\}/@UNDEFINED/' ${DIR_ASSETS}/env.json | tr -d "\n")
  escaped_conf=$(printf '%s\n' "$envJsonAsString" | sed -e 's/[\/&]/\\&/g')
  injectScript="window[\"APP_CONFIG\"]=$escaped_conf;"
  export INJECTED_ENV=$injectScript
  echo "Create and add 'INJECTED_ENV' generate variable from ${DIR_ASSETS}/env.json to CONFIG_ENV list of variables"
  config_env_names=$config_env_names" INJECTED_ENV"
else
  echo "Missing ${DIR_ASSETS}/env.json file to replace 'INJECTED_ENV'"  
fi



# Update environment variables in the nginx configuration files
for file in ${DIR_SERVER_BLOCKS}/*.conf ${DIR_LOCATION}/*.conf; do
  echo "Replacing '@@<var>' placeholders in file: $file"
  for item in ${config_env_names[@]}; do
    value=$(printf '%s\n' "${!item}")
    # echo "Replace '$item' in $file"
    sed -i "s|@@$item|$value|g" $file
  done
done

echo "Done"
exec "$@"
