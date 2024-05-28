#!/bin/bash

set -eu

SECRETS_DIR=./test/run/secrets
#DEBUG_SECRETS=1

echo
echo '## Starting test script'
echo

MY_VAR_2='var_set_beforehand'
YET_ANOTHER_SECRET='another_var_alredy_set'

# results according to folder "test/run/secrets"
declare -A expected_values=(
    [MYVAR1]=value-of-myvar1
    [MY_VAR_2]=var_set_beforehand
    [MY_VAR_3]=value-of-my_var_3
    [SOME_OTHER_VERSIONED_VAR]=value-of-some_other_versioned_var--v100
    [SOME_VERSIONED_VAR]=value-of-some_versioned_var--v2
    [INVALID_VERSION_V1]=value-of-invalid-version-v1
    [YET_ANOTHER_SECRET]=another_var_alredy_set
    [CAPS_VAR]=value-of-CAPS_VAR--V2
    [VAR_WITH_REVISION]=value-for-var-with-revision--r2
)

echo "## Calling target script 'secrets-to-env.sh'"
echo
source docker-secrets-to-env.sh
echo
echo "## Target script finished, back to test script'"
echo
echo "## Testing results..."
echo


for var_name in "${!expected_values[@]}"
do
    printf "%-45s" "Testing var '$var_name': "
    if [[ "${!var_name}" == "${expected_values[$var_name]}" ]]
    then
        echo "OK - PASSED"
    else
        echo "Unexpected value - FAILED"
        echo "  Expected value was: '${expected_values[$var_name]}'"
        echo "  Variable value is:  '${!var_name}'"
    fi
done

echo



