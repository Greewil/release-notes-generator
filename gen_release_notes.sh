#!/usr/bin/env bash

#/ Usage: gen-release-notes [-v | --version] [-h | --help] <interval> [<options>]
#/
#/ Standalone commands:
#/     -h, --help               show help text
#/     -v, --version            show version
#/
#/ Interval:
#/     You should specify two commit pointers interval '<commit-pointer>..<commit-pointer>'.
#/     Commit pointer can be:
#/        - commit hash
#/        - commit tag
#/        - 'HEAD'
#/     Interval examples:
#/        - bc483c1..HEAD (equals to bc483c1..)
#/        - v1.0.1..v1.1.0
#/
#/ Options:
#/     -r, --raw-logs           show only list of commit titles
#/     -s, --short              show only titles of commits without message body
#/     -f <file_name>           save output to file
#/
#/     Mutually exclusive parameters: short, raw-logs
#/
#/ Generate release notes for your project.
#/ Script can generate release notes for your project from any directory inside of your local repository.
#/ Project repository: https://github.com/Greewil/release-notes-generator
#
# Written by Shishkin Sergey <shishkin.sergey.d@gmail.com>

# Current generator version
RELEASE_NOTES_GENERATOR_VERSION='0.1.0'

# generator global variables (Please don't modify!)
REPO_HTTP_URL=''
ALL_COMMITS=''
RELEASE_NOTES=''

# Output colors
APP_NAME='gen-release-notes'
NEUTRAL_COLOR='\e[0m'
RED='\e[1;31m'        # for errors
YELLOW='\e[1;33m'     # for warnings
BROWN='\e[0;33m'      # for inputs
LIGHT_CYAN='\e[1;36m' # for changes

# Console input variables (Please don't modify!)
# command type:
COMMAND=''
# data input:
SPECIFIED_INTERVAL=''
SPECIFIED_OUTPUT_FILE=''
# arguments:
ARGUMENT_SHORT='false'
ARGUMENT_RAW='false'
ARGUMENT_SAVE_OUTPUT='false'


function _show_function_title() {
  printf '\n'
  echo "$1"
}

function _show_error_message() {
  message=$1
  echo -en "$RED($APP_NAME : ERROR) $message$NEUTRAL_COLOR\n"
}

function _show_warning_message() {
  message=$1
  echo -en "$YELLOW($APP_NAME : WARNING) $message$NEUTRAL_COLOR\n"
}

function _show_updated_message() {
  message=$1
  echo -en "$LIGHT_CYAN($APP_NAME : CHANGED) $message$NEUTRAL_COLOR\n"
}

function _show_invalid_usage_error_message() {
  message=$1
  _show_error_message "$message"
  echo 'Use "gen-release-notes --help" to see available commands and options information'
}

function _exit_if_using_multiple_commands() {
  last_command=$1
  if [ "$COMMAND" != '' ]; then
    _show_invalid_usage_error_message "You can't use both commands: '$COMMAND' and '$1'!"
    exit 1
  fi
}

function _get_initial_commit_reference() {
  git rev-list --max-parents=0 HEAD
}

function _get_repo_url() {
#  git@github.com:Greewil/one-line-installer.git
  url=$(git remote get-url origin)
  if [[ "$url" = 'git@'* ]]; then
    url="${url/git@/}"
    url="${url/:/\/}"
    url="https://${url/.git/}"
    REPO_HTTP_URL="$url"
  else
    REPO_HTTP_URL="$url"
  fi
}

function _get_commit_tags() {
  ALL_COMMITS=$(git log "$SPECIFIED_INTERVAL" --oneline --pretty=format:%H) || exit 1
#  echo "$ALL_COMMITS"
}

function _get_commit_info_by_name() {
  commit_hash=$1
  format=$2
  git log "$commit_hash" -n 1 --pretty=format:"$format"
}

function _get_commit_titles() {
  echo TODO # TODO
}

function get_raw_logs() {
  _show_function_title "raw release notes:"
  git log "$SPECIFIED_INTERVAL" --oneline --pretty=format:%s
}

function get_short_release_notes() {
  _show_function_title "short release notes:"
  _get_commit_tags
  echo "$ALL_COMMITS" | while read -r line; do
    commit_title=$(_get_commit_info_by_name "$line" '"%s"')
    commit_link="[commit]($REPO_HTTP_URL/commit/$line)"
    printf "\n%s\n" "$commit_title $commit_link"
  done
}

function get_default_release_notes() {
  get_short_release_notes
}

function show_generator_version() {
  echo "gen-release-notes version: $RELEASE_NOTES_GENERATOR_VERSION"
}

function show_help() {
  grep '^#/' <"$0" | cut -c4-
}


while [[ $# -gt 0 ]]; do
  case "$1" in
  -h|--help)
    _exit_if_using_multiple_commands "$1"
    COMMAND='--help'
    shift ;;
  -v|--version)
    _exit_if_using_multiple_commands "$1"
    COMMAND='--version'
    shift ;;
  *..*)
    _exit_if_using_multiple_commands "$1"
    COMMAND='gen-release-notes'
    SPECIFIED_INTERVAL="$1"
    shift ;;
  -r|--raw-logs)
    ARGUMENT_RAW='true'
    shift ;;
  -s|--short)
    ARGUMENT_SHORT='true'
    shift ;;
  -*|--*)
    _show_invalid_usage_error_message "Unknown option '$1'!"
    exit 1 ;;
  *)
    _show_invalid_usage_error_message "Unknown command '$1'!"
    exit 1 ;;
  esac
done

_get_repo_url

case "$COMMAND" in
--help)
  show_help
  exit 0
  ;;
--version)
  show_generator_version
  exit 0
  ;;
gen-release-notes)
  if [ "$ARGUMENT_RAW" = 'true' ]; then
    get_raw_logs
  elif [ "$ARGUMENT_SHORT" = 'true' ]; then
    get_short_release_notes
  else
    get_default_release_notes
  fi
  exit 0
  ;;
esac
