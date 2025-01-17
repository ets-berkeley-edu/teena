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
echo "------------------------"; echo

# ----

echo 'Which browser do we want to use? Enter 1 or 2. '

browser_options=("chrome" "firefox")

select opt in "${browser_options[@]}"; do
  case ${opt} in
  "chrome")
    browser="chrome"
    break
    ;;
  "firefox")
    browser="firefox"
    break
    ;;
  *)
    echo "Answer truly, or you will browse in vain"
    exit 1
    ;;
  esac
done

echo

# ----

echo 'Head or no head? Enter 1 or 2. '

headless_options=("regular" "headless")

select opt in "${headless_options[@]}"; do
  case ${opt} in
  "regular")
    headless=false
    break
    ;;
  "headless")
    headless=true
    break
    ;;
  esac
done

echo

# ----

options=("Ripley" "SuiteC")

tool_being_tested=''

function set_tool_being_tested {
    case "${1}" in
        "Ripley")
            tool_being_tested='ripley'
            friendly_tool_name=${options[0]}
            ;;
        "SuiteC")
            tool_being_tested='squiggy'
            friendly_tool_name=${options[1]}
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
    echo "Enter snippet (e.g., 'e_grades_export' or 'roster') to match the ${tool_being_tested} Selenium script(s) you want to run."
    echo "Blank input will run all tests."; echo
    echo -n "    > "

    read test_suite
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

suffix="${DATE}"

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
    rake BROWSER="${browser}" HEADLESS="${headless}" VERSION="${summary}" USER="${username}" PASS="${password}" "${tool_being_tested}"
else
    echo; echo "Running '${test_suite}' tests of ${friendly_tool_name} v${version}"
    echo
    rake BROWSER="${browser}" HEADLESS="${headless}" SCRIPTS="${test_suite}" VERSION="${summary}" USER="${username}" PASS="${password}" "${tool_being_tested}"
fi

echo
echo "--------------------------------"; echo
echo "  We are done. Teena thanks you."; echo
echo "--------------------------------"
echo; echo

exit 0
