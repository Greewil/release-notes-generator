#!/usr/bin/env bash

function _gen_release_notes_completion()
{
  latest="${COMP_WORDS[$COMP_CWORD]}"
  prev="${COMP_WORDS[$COMP_CWORD - 1]}"
  # if there are no commands yet search for commands
  words="-h --help -v --version --show-repo-config
         --raw-titles -f -a --all-commits --single-list -lt --from-latest-tag --short --format"

  case "$prev" in
  -f)
    words=""  # TODO use directory completion
    ;;
  --format)
    words=""
    ;;
  esac

  # remove completion if standalone options was typed
  for i in "${COMP_WORDS[@]}"; do
    case "$i" in
    -h|--help)
      words=""
      ;;
    -v|--version)
      words=""
      ;;
    --show-repo-config)
      words=""
      ;;
    esac
  done

  # shellcheck disable=SC2207
  COMPREPLY=( $(compgen -W "$words" -- "$latest") )
}

complete -F _gen_release_notes_completion gen-release-notes
