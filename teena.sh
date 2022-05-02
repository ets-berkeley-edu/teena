#!/usr/bin/env bash

# Abort immediately if a command fails
set -e

trap "killall background" EXIT

echo
echo "------------------------"; echo
echo "  Teena welcomes you."; echo;
echo "------------------------"; echo
echo "  You can skip prompts by setting the proper environment variables:"; echo
echo "  For example,"
echo "    export TEENA__TOOL=\"SuiteC\""
echo "    export TEENA__TOOL_VERSION=\"3.4\""
echo "    export TEENA__TEST_SUITE_KEYWORD=\"whiteboard\""
echo "    export TEENA__LOG_FILENAME_SNIPPET=\"whiteboard_mgmt\""; echo
echo "------------------------"; echo

options=("BOA" "Junction" "SuiteC")

tool_being_tested=''

function set_tool_being_tested {
    case "${1}" in
        "BOA")
            tool_being_tested='boac'
            friendly_tool_name=${options[0]}
            test_dept=$(grep '^  test_dept' "${HOME}/.webdriver-config/settings.yml" | awk '{print $NF}')
            echo; echo "Boa will be tested with test_dept: ${test_dept}"; echo
            ;;
        "Junction")
            tool_being_tested='junction'
            friendly_tool_name=${options[1]}
            ;;
        "SuiteC")
            tool_being_tested='squiggy'
            friendly_tool_name=${options[2]}
            ;;
        *)
            echo "[ERROR] Invalid option: ${REPLY}"
            exit 1
            ;;
    esac
}

tool="${TEENA__TOOL}"
version="${TEENA__TOOL_VERSION}"
test_suite="${TEENA__TEST_SUITE_KEYWORD}"
log_filename_snippet="${TEENA__LOG_FILENAME_SNIPPET}"

# ----

if [ -z "${tool}" ]
then
    PS3=$'\nWhich tool are you testing? '

    select opt in "${options[@]}"; do
        set_tool_being_tested "${opt}"
        break
    done
else
    set_tool_being_tested "${tool}"
fi

# ----

if [ -z "${version}" ]
then
    echo; echo "Enter version of ${tool_being_tested} being tested (e.g., '2.15')."
    echo; echo -n "    > "

    read version
fi

# ----

if [ -z "${test_suite}" ]
then
    echo
    echo "Enter snippet (e.g., 'user_role' or 'user_role_coe') to match the ${tool_being_tested} Selenium script(s) you want to run."
    echo "Blank input will run all tests."; echo
    echo -n "    > "

    read test_suite
fi

# ----

if [ -z "${log_filename_snippet}" ]
then
    echo; echo "Enter arbitrary keyword (e.g., 'COENG') to add to log file name. Hit return to skip."
    echo; echo -n "    > "

    read log_filename_snippet
    echo; echo
fi

# ----

echo
echo "Enter your username. Hit return to skip."
echo
printf "    > "

read -s username

# ----

echo
echo "Enter your password. Hit return to skip."
echo
printf "    > "

read -s password

# ----

DATE=$(date '+%Y-%m-%d-%H%M%S')

[[ "${log_filename_snippet}" ]] && suffix="${log_filename_snippet}-${DATE}" || suffix="${DATE}"

summary="${tool_being_tested}-v${version}-${test_suite:-'all'}-${suffix}"

echo
echo "--------------------------------"; echo
echo "  Look for output in log file: "
echo "  ~/webdriver-output/test-results/test-results-${summary}-*.log"; echo
echo "--------------------------------"; echo

if [[ -z "${test_suite}" ]]
then
    echo; echo "Running ALL tests of ${friendly_tool_name} v${version}"
    echo
    rake VERSION="${summary}" USER="${username}" PASS="${password}" "${tool_being_tested}"
else
    echo; echo "Running '${test_suite}' tests of ${friendly_tool_name} v${version}"
    echo
    rake SCRIPTS="${test_suite}" VERSION="${summary}" USER="${username}" PASS="${password}" "${tool_being_tested}"
fi

echo
echo "--------------------------------"; echo
echo "  We are done. Teena thanks you."; echo
echo "--------------------------------"
echo; echo

exit 0
