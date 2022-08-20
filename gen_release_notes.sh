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
#/        - 'HEAD' for latest commit
#/     Interval examples:
#/        - bc483c1..HEAD (equals to bc483c1..)
#/        - v1.0.1..v1.1.0
#/
#/ Options:
#/     -r, --raw                show only list of commit titles
#/     -s, --short              show only titles of commits without message body
#     -f <file_name>           save output to file
#/     -a, --all-commits        release notes will be generated from all commits which are inside of specified interval
#/                              (by default release notes will be generated only from conventional commits)
#/     --single-list            release notes will be generated as single list of commit messages
#/                              (by default log messages will be grouped by conventional commit types)
#/
#/     Mutually exclusive parameters: (-s | --short), (-r | --raw-logs)
#/
#/ Custom configuration for projects
#/     If you want to use custom group headers or custom release header you can specify them in .gen_release_notes.
#/     Your .gen_release_notes file should be placed in root folder of your repository.
#/
#/     To specify group headers put it in variable named "<CORRESPONDING_TYPE>_GROUP_HEADER" (f.e. if you want to specify
#/     'feat' type header as "Features" you should write "FEAT_GROUP_HEADER='Features'" line to your .gen_release_notes).
#/     To specify release header text add "RELEASE_HEADER='<your static header>'" line to your .gen_release_notes.
#/
#/     Your can find examples in https://github.com/Greewil/release-notes-generator/tree/main/project_configuration_examples
#/
#/ Generate release notes for your project.
#/ Script can generate release notes for your project from any directory inside of your local repository.
#/ Project repository: https://github.com/Greewil/release-notes-generator
#
# Written by Shishkin Sergey <shishkin.sergey.d@gmail.com>

# Current generator version
RELEASE_NOTES_GENERATOR_VERSION='0.1.1'

# all conventional commit types (Please don't modify!)
CONVENTIONAL_COMMIT_TYPES=('build' 'ci' 'chore' 'docs' 'feat' 'fix' 'pref' 'refactor' 'revert' 'style' 'test')

# generator global variables (Please don't modify!)
ROOT_REPO_DIR=''
REPO_HTTP_URL=''
ALL_COMMITS=''
RELEASE_NOTES_TYPE_GROUPS=() # for each CONVENTIONAL_COMMIT_TYPES
for i in $(seq 1 ${#CONVENTIONAL_COMMIT_TYPES[@]}); do RELEASE_NOTES_TYPE_GROUPS+=(''); done
UNTYPED_COMMITS=''           # for commits without types

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
    _show_invalid_usage_error_message "You can't use both commands: '$COMMAND' and '$last_command'!"
    exit 1
  fi
}

function _get_root_repo_dir() {
  ROOT_REPO_DIR=$(git rev-parse --show-toplevel) || {
    _show_error_message "Can't find root repo directory!"
    echo
    return 1
  }
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

function _get_initial_commit_reference() {
  git rev-list --max-parents=0 HEAD
}

function _get_type_index_by_name() {
  type_name=$1
  for i in "${!CONVENTIONAL_COMMIT_TYPES[@]}"; do
    if [ "$type_name" = "${CONVENTIONAL_COMMIT_TYPES[$i]}" ]; then
      echo "$i"
    fi
  done
}

function _collect_all_commits() {
  ALL_COMMITS="$(git log "$SPECIFIED_INTERVAL" --oneline --pretty=format:%H)"
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
  additional_info=''
  while read -r line; do
    additional_info="$additional_info"$'\n   '"$line"
  done < <(_get_commit_info_by_hash "$commit_hash" "$additional_info_format")
  if [ "$ARGUMENT_RAW" = 'true' ]; then
    printf "\n* %s" "$commit_title"
  else
    printf "\n* %s\n   %s" "$commit_title" "$commit_link"
    echo "$additional_info"
  fi
}

function _generate_commit_groups() {
  while read -r commit_hash; do
    commit_title=$(_get_commit_info_by_hash "$commit_hash" '%s')
    if [[ "$commit_title" =~ ^(build|ci|chore|docs|feat|fix|pref|refactor|revert|style|test)(\([a-z]+\))?!?:\ (.*) ]]; then
      type_index=$(_get_type_index_by_name "${BASH_REMATCH[1]}")
      title_description_only="${BASH_REMATCH[3]}"
    else
      type_index=''
      title_description_only="$commit_title"
    fi
    if [ "$ARGUMENT_ALL_COMMITS" = 'true' ] || [[ "$type_index" != '' ]]; then
      if [ "$ARGUMENT_SHORT" = 'true' ]; then
        additional_info_format=''
      else
        additional_info_format='(%cn)%n%n%b'
      fi
      log_message=$(_get_log_message "$commit_hash" "$title_description_only" "$additional_info_format")
      if [ "$ARGUMENT_SINGLE_LIST" = 'true' ]; then
        UNTYPED_COMMITS="$UNTYPED_COMMITS$log_message"
      else
        if [ "$type_index" = '' ]; then
          UNTYPED_COMMITS="$UNTYPED_COMMITS$log_message"
        else
          RELEASE_NOTES_TYPE_GROUPS[$type_index]="${RELEASE_NOTES_TYPE_GROUPS[$type_index]}$log_message"
        fi
      fi
    fi
  done < <(echo "$ALL_COMMITS")
}

function _get_single_list_release() {
  echo "$UNTYPED_COMMITS"
}

function _get_group_header() {
  type_name=$1
  header_variable_name="$(echo "$type_name" | tr '[:lower:]' '[:upper:]')_GROUP_HEADER"
  echo "${!header_variable_name}"
}

function _get_grouped_release() {
  for i in "${!RELEASE_NOTES_TYPE_GROUPS[@]}"; do
    if [[ "${RELEASE_NOTES_TYPE_GROUPS[$i]}" != '' ]]; then
      printf "\n"
      group_header=$(_get_group_header "${CONVENTIONAL_COMMIT_TYPES[$i]}")
      echo "## $group_header"
      echo "${RELEASE_NOTES_TYPE_GROUPS[$i]}"
    fi
  done
  if [[ "$UNTYPED_COMMITS" != '' ]]; then
    printf "\n"
    echo "## Untyped commits"
    echo "$UNTYPED_COMMITS"
  fi
}

function _get_release_notes_text() {
  echo "$RELEASE_HEADER"
  if [ "$ARGUMENT_SINGLE_LIST" = 'true' ]; then
    _get_single_list_release
  else
    _get_grouped_release
  fi
}

function get_release_notes() {
  _collect_all_commits || exit 1
  _generate_commit_groups || exit 1
  _get_release_notes_text || exit 1
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
  ..*)
    _exit_if_using_multiple_commands "$1"
    COMMAND='gen-release-notes'
    begin_ref=$(_get_initial_commit_reference)
    SPECIFIED_INTERVAL="$begin_ref$1"
    shift ;;
  *..*)
    _exit_if_using_multiple_commands "$1"
    COMMAND='gen-release-notes'
    SPECIFIED_INTERVAL="$1"
    shift ;;
  -r|--raw)
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
  -*)
    _show_invalid_usage_error_message "Unknown option '$1'!"
    exit 1 ;;
  *)
    _show_invalid_usage_error_message "Unknown command '$1'!"
    exit 1 ;;
  esac
done

_get_repo_url || exit 1
_get_root_repo_dir || exit 1
[ -f "$ROOT_REPO_DIR/.gen_release_notes" ] && (source "$ROOT_REPO_DIR/.gen_release_notes" || exit 1)

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
  get_release_notes
  exit 0
  ;;
esac
