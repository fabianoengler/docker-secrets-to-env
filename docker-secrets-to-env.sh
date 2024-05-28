#!/bin/false  ## this file is meant to be sourced


# MIT License
#
# Copyright (c) 2024 Fabiano Engler Neto
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
#  docker-secrets-to-env
#  https://github.com/fabianoengler/docker-secrets-to-env
#  v1.0
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
#  This script reads docker secrets files from /run/secrets and export
#  them as environment variables. It changes the filename to uppercase
#  and replaces hypens (-) with underscores (_). For example, a secret
#  named 'my-secret-key' becomes env variable 'MY_SECRET_KEY'.
#
#  You can have multiple versions (also called revisions or rotations) of a
#  secret by appending the suffix '--v{n}' or '--r{n}' to the secret name,
#  where {n} can be any non-negative integer. In case there are multiple
#  versions/revisions of the same secret, the highest number is used.
#  The version/revision suffix is removed from the env variable name.
#
#  The double hyphen for version is used to prevent conflict with already
#  exiting variables names ending in -V{N}. For example, suppose you have
#  a legacy API and you start calling your new API as v2 but you still
#  need to access the old API, you could have env variables names
#  like API_V1 and API_V2.
#
#  For example, the following secret names would be mapped as the
#  following env variables names:
#
#  /run/secret/db-password      DB_PASSWORD
#  /run/secret/api-url          API_URL
#  /run/secret/cache-key        (ignored in favor of --v3)
#  /run/secret/cache-key--v2    (ignored in favor of --v3)
#  /run/secret/cache-key--v3    CACHE_KEY
#  /run/secret/api-v1           API_V1
#  /run/secret/api-v2           (ignored in favor of --v3)
#  /run/secret/api-v2--v2       API_V2
#  
#
#  Usage:
#
#  - Download this file to your project:
#  ```
#  curl -O https://raw.githubusercontent.com/fabianoengler/docker-secrets-to-env/master/docker-secrets-to-env.sh
#  ```
#
#  - Add a line to source it from your entrypoint script:
#  ```
#  source docker-secrets-to-env.sh
#  ```
#
#  - That's it, all secrets on /run/secrets will be exposed as environment
#    variables now.
#
#  - If you want to see what the script is doing, set the
#    variable DEBUG_SECRETS before the source line:
#  ```
#  DEBUG_SECRETS=1
#  source docker-secrets-to-env.sh
#  ```
#
#  - If you want to change the directory where the script looks for the
#    secrets files, you can set the variable SECRETS_DIR before sourcing
#    the script.
#

if [ -z "$BASH" ]
then
    echo "[ERROR] This script requires bash shell"
else

    : ${SECRETS_DIR:=/run/secrets}
    : ${DEBUG_SECRETS:=}

    if [[ "${DEBUG_SECRETS^^}" == "FALSE" || "$DEBUG_SECRETS" == 0 ]]
    then
        unset DEBUG_SECRETS
    fi


    _log_secrets() {
        declare level="${1^^}"
        shift 
        [[ -z "${DEBUG_SECRETS:-}" && "$level" == "DEBUG" ]] && return
        printf "[%s] %s\n" "$level" "$*"
    }

    _parse_secrets() {
        SECRETS_DIR="${SECRETS_DIR%%/}"
        if ! [[ -d "$SECRETS_DIR" ]]
        then
            _log_secrets INFO "Secrets dir not found: \"$SECRETS_DIR\""
            return
        fi

        declare -a orig_secret_names
        declare -A mapped_env_names
        declare -A mapped_secret_names
        declare count i name env_name value file_name line
        pushd "$SECRETS_DIR" > /dev/null
        while read line; do
            _log_secrets DEBUG "Secret file detected: '$SECRETS_DIR/$line'"
            [[ -n "$line" ]] && orig_secret_names+=( "$line" )
        done 3>&1 <<< "$(
            for f in *
            do
                if [[ -f "$f" ]]
                then
                    if [[ "$f" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]
                    then
                        printf "%s\n" "$f"
                    else
                        _log_secrets DEBUG "Secret file ignored (invalid name): '$SECRETS_DIR/$f'" >&3
                    fi
                else
                    _log_secrets DEBUG "Secret file ignored (non-regular file): '$SECRETS_DIR/$f'" >&3
                fi
            done | sort -V
        )"

        count=${#orig_secret_names[@]}
        if [[ $count -eq 0 ]]
        then
            _log_secrets INFO "No secrets found at \"$SECRETS_DIR\""
            return
        fi
        for (( i=count-1 ; i>=0 ; i-- ))
        do
            name="${orig_secret_names[$i]}"
            env_name=$( printf "%s" "$name" | sed 's/--[vVrR][0-9]\+$//' )
            env_name=${env_name^^}
            env_name=${env_name//-/_}
            if ! [[ -v "mapped_env_names[$env_name]" ]]
            then
                mapped_env_names["$env_name"]="$name"
            fi
            mapped_secret_names["$name"]="$env_name"
        done

        for name in "${orig_secret_names[@]}"
        do
            env_name="${mapped_secret_names[$name]}"
            selected_name="${mapped_env_names[$env_name]}"
            if [[ "$name" == "$selected_name" ]]
            then
                file_name="${SECRETS_DIR%/}/${name}"
                if [[ -v "$env_name" ]]
                then
                    _log_secrets WARN "Env variable '$env_name' already defined, ignoring secret '$file_name'"
                else
                    _log_secrets INFO "Setting Env variable '$env_name' from secret '$file_name'"
                    value=$(<"$name")
                    declare -g -x "$env_name"="$value"
                fi
            else
                _log_secrets DEBUG "Ignoring secret '$name' in favor of higher precedence '$selected_name'"
            fi
        done
        popd > /dev/null
    }

    _parse_secrets
    unset _parse_secrets _log_secrets

fi



