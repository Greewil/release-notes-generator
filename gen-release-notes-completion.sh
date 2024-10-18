#!/usr/bin/env bash

#function _remove_word_from_option_list() {
#  #
#}

function _gen_release_notes_completion() {
  latest="${COMP_WORDS[$COMP_CWORD]}"
  prev="${COMP_WORDS[$COMP_CWORD - 1]}"
  # if there are no commands yet search for commands
  all_standalone_commands="-h --help -v --version --show-repo-config"
  all_options="-i --raw-titles -f -a --all-commits --single-list -lt --from-latest-tag -s --short --format"
  options="$all_options "  # should be ' ' at the end for correct extraction
  words="$all_standalone_commands $options "  # should be ' ' at the end for correct extraction

  # run throw all typed words
  for i in "${COMP_WORDS[@]}"; do

    # remove completion if standalone options was typed
    IFS=' ' read -ra ADDR <<< "$all_standalone_commands"
    for option_word in "${ADDR[@]}"; do
      if [ "$i" = "$option_word" ]; then
        words=""
      fi
    done

    # if any option was used remove redundant hints (standalone_commands, option aliases and mutually exclusive options)
    IFS=' ' read -ra ADDR <<< "$all_options"
    for option_word in "${ADDR[@]}"; do
      if [ "$i" = "$option_word" ]; then
        # remove mutually exclusive options and option aliases
        case "$option_word" in
        -a|--all-commits)
          options=${options/-a /}
          options=${options/--all-commits /}
          ;;
        -lt|--from-latest-tag)
          options=${options/-lt /}
          options=${options/--from-latest-tag /}
          ;;
        -s|--short)
          options=${options/-s /}
          options=${options/--short /}
          # mutually exclusive options
          options=${options/--format /}
          ;;
        --format)
          options=${options/--format /}
          # mutually exclusive options
          options=${options/-s /}
          options=${options/--short /}
          ;;
        esac
        options=${options/$option_word /}
        words="$options"
      fi
    done

  done

  # waiting for option value to pass
  case "$prev" in
  -i)
    words=""
    ;;
  -f)
    words=""  # TODO use directory completion
    ;;
  --format)
    words=""
    ;;
  esac

  # shellcheck disable=SC2207
  COMPREPLY=( $(compgen -W "$words" -- "$latest") )
}

complete -F _gen_release_notes_completion gen-release-notes
