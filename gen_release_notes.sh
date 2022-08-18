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
#/     -a, --all-commits        release notes will be generated from all commits which are inside of specified interval
#/                              (by default release notes will be generated only from conventional commits)
#/     --single-list            release notes will be generated as single list of commit messages
#/                              (by default log messages will be grouped by conventional commit tags)
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

# all conventional commit tags (Please don't modify!)
CONVENTIONAL_COMMIT_TAGS=('build' 'ci' 'chore' 'docs' 'feat' 'fix' 'pref' 'refactor' 'revert' 'style' 'test')

# generator global variables (Please don't modify!)
REPO_HTTP_URL=''
ALL_COMMITS=''
RELEASE_NOTES_TAG_GROUPS=() # for each CONVENTIONAL_COMMIT_TAGS
for i in $(seq 1 ${#CONVENTIONAL_COMMIT_TAGS[@]}); do RELEASE_NOTES_TAG_GROUPS+=(''); done
NO_TAG_COMMITS=''           # for commits without tags

# default configuration:
RELEASE_HEADER=''
BUILD_GROUP_HEADER='Build system and external dependencies'
CI_GROUP_HEADER='CI configuration files and scripts'
CHORE_GROUP_HEADER='Chores'
DOCS_GROUP_HEADER='Documentation'
FEAT_GROUP_HEADER='Features'
FIX_GROUP_HEADER='Bug fixes'
PREF_GROUP_HEADER='Performance improvements'
REFACTOR_GROUP_HEADER='Refactoring'
REVERT_GROUP_HEADER='Reverts'
STYLE_GROUP_HEADER='Formatting'
TEST_GROUP_HEADER='Tests'

# Output colors
APP_NAME='gen-release-notes'
NEUTRAL_COLOR='\e[0m'
RED='\e[1;31m'        # for errors
YELLOW='\e[1;33m'     # for warnings
BROWN='\e[0;33m'      # for inputs
LIGHT_CYAN='\e[1;36m' # for changes

# Console input variables (Please don't modify!)
COMMAND=''
SPECIFIED_INTERVAL=''
SPECIFIED_OUTPUT_FILE=''
ARGUMENT_SHORT='false'
ARGUMENT_RAW='false'
ARGUMENT_SAVE_OUTPUT='false'
ARGUMENT_ALL_COMMITS='false'
ARGUMENT_SINGLE_LIST='false'


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
  origin_url=$(git remote get-url origin)
  if [[ "$origin_url" = 'git@'* ]]; then
    url="${origin_url/git@/}"
    url="${url/:/\/}"
    url="https://${url/.git/}"
    REPO_HTTP_URL="$url"
  else
    REPO_HTTP_URL="$origin_url"
  fi
}

function _get_tag_index_by_commit_title() {
  title=$1
  for i in "${!CONVENTIONAL_COMMIT_TAGS[@]}"; do
    [[ "$title" = "${CONVENTIONAL_COMMIT_TAGS[$i]}"* ]] && echo "$i"
  done
}

function _collect_all_commits() {
  ALL_COMMITS=$(git log "$SPECIFIED_INTERVAL" --oneline --pretty=format:%H) || return 1
}

function _get_commit_info_by_hash() {
  commit_hash=$1
  format=$2
  git log "$commit_hash" -n 1 --pretty=format:"$format"
}

function _get_log_message() {
  commit_hash=$1
  commit_title=$2
  additional_info_format=$3
  commit_link="([commit]($REPO_HTTP_URL/commit/$commit_hash))"
  additional_info=$(_get_commit_info_by_hash "$commit_hash" "$additional_info_format")
  printf "\n* %s\n%s\n%s" "$commit_title" "$commit_link" "$additional_info"
}

function _generate_commit_groups() {
  while read -r commit_hash; do
    commit_title=$(_get_commit_info_by_hash "$commit_hash" '%s')
    tag_index=$(_get_tag_index_by_commit_title "$commit_title")
    if [ "$ARGUMENT_ALL_COMMITS" = 'true' ] || [[ "$tag_index" != '' ]]; then
      if [ "$ARGUMENT_SHORT" = 'true' ]; then
        additional_info_format=''
      else
        additional_info_format='(%cn)%n%n%b'
      fi
      log_message=$(_get_log_message "$commit_hash" "$commit_title" "$additional_info_format")
      if [ "$ARGUMENT_SINGLE_LIST" = 'true' ]; then
        NO_TAG_COMMITS="$NO_TAG_COMMITS$log_message"
      else
        if [ "$tag_index" = '' ]; then
          NO_TAG_COMMITS="$NO_TAG_COMMITS$log_message"
        else
          RELEASE_NOTES_TAG_GROUPS[$tag_index]="${RELEASE_NOTES_TAG_GROUPS[$tag_index]}$log_message"
        fi
      fi
    fi
  done < <(echo "$ALL_COMMITS")
}

function _get_single_list_release() {
  echo "$NO_TAG_COMMITS"
}

function _get_group_header() {
  tag_name=$1
  header_variable_name="$(echo "$tag_name" | tr '[:lower:]' '[:upper:]')_GROUP_HEADER"
  echo ${!header_variable_name}
}

function _get_groupped_release() {
  for i in "${!RELEASE_NOTES_TAG_GROUPS[@]}"; do
    if [[ "${RELEASE_NOTES_TAG_GROUPS[$i]}" != '' ]]; then
      printf "\n"
      group_header=$(_get_group_header "${CONVENTIONAL_COMMIT_TAGS[$i]}")
      echo "## $group_header"
      echo "${RELEASE_NOTES_TAG_GROUPS[$i]}"
    fi
  done
  if [[ "$NO_TAG_COMMITS" != '' ]]; then
    printf "\n"
    echo "--- untagged ---"
    echo "$NO_TAG_COMMITS"
  fi
}

function _get_release_notes() {
  echo "$RELEASE_HEADER"
  if [ "$ARGUMENT_SINGLE_LIST" = 'true' ]; then
    _get_single_list_release
  else
    _get_groupped_release
  fi
}

function get_raw_logs() {
  _show_function_title "raw release notes:"
  git log "$SPECIFIED_INTERVAL" --oneline --pretty=format:%s
}

function get_default_release_notes() {
  _collect_all_commits || exit 1
  _generate_commit_groups || exit 1
  _get_release_notes || exit 1
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
  --single-list)
    ARGUMENT_SINGLE_LIST='true'
    shift ;;
  -a|--all-commits)
    ARGUMENT_ALL_COMMITS='true'
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
  else
    get_default_release_notes
  fi
  exit 0
  ;;
esac
