#!/bin/bash

doFile() {
  infile="${1}"
  comment="${2}"
  type="${3}"
  transl="${4}"
  tmpfile="$(mktemp)"
  outfile="$(mktemp)"
  echo "${comment}_${type}" >"${tmpfile}"
  case "${type}" in
    "in")
      lines="1,2000"
      ;;
    "out")
      lines="4097,6096"
      ;;
    *)
      lines="1,1"
      ;;
  esac
  sed -n "${lines} p" "${infile}" >>"${tmpfile}"
  while read line
  do
    renum='^[01]+$'
    rex='^x+$'
    len="${#line}"
    if [[ "${line}" =~ ${renum} ]] && [ "${transl}" != "notr" ]
    then
      printf "0x%0$((len/4))x\n" "$((2#${line}))" >>"${outfile}"
    elif [[ "${line}" =~ ${rex} ]] && [ "${transl}" != "notr" ]
    then
      printf "0x%$((len/4))s\n" | tr ' ' 'x' >>"${outfile}"
    else
      echo "${line}" >>"${outfile}"
    fi
  done <"${tmpfile}"
  rm -f "${tmpfile}"
  echo "${outfile}"
}

cd "$(dirname "$(readlink -f "${0}")")"
benchmark="${1}"
transl="${2}"
file_cmp="benchmarks/butterworth/${benchmark}/compare/GM_out.txt"
file_new="build/butterworth/${benchmark}/simulation/GM_out.txt"

file_cmp_in="$(doFile "${file_cmp}" "cmp" "in" "${transl}")"
file_cmp_out="$(doFile "${file_cmp}" "cmp" "out" "${transl}")"
file_new_in="$(doFile "${file_new}" "new" "in" "${transl}")"
file_new_out="$(doFile "${file_new}" "new" "out" "${transl}")"

paste "${file_cmp_in}" "${file_cmp_out}" "${file_new_out}" "${file_new_in}" | column -t

rm -f "${file_cmp_in}"
rm -f "${file_cmp_out}"
rm -f "${file_new_in}"
rm -f "${file_new_out}"
