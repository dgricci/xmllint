#!/bin/bash
#
# Vérifie si un fichier XML est bien formé et valide
#
# Constantes :
VERSION="0.0.1"
# Variables globales :
unset show
#
# Exécute ou affiche une commande
# $1 : code de sortie en erreur
# $2 : commande à exécuter
run () {
  local code=$1
  local cmd=$2
  if [ -n "${show}" ] ; then
    echo "cmd: ${cmd}"
  else
    eval ${cmd}
  fi
  [ $? -ne 0 ] && {
    echo "Oops #################"
    exit ${code}
  }
  exit 0
}
#
# Affichage d'erreur
# $1 : code de sortie
# $@ : message
echoerr () {
    local code=$1
    shift
    echo "$@" 1>&2
    usage ${code}
}
#
# Usage du shell :
# $1 : code de sortie
usage () {
  cat >&2 <<EOF
usage: `basename $0` [--help -h] | [pathToXSD] pathToXML

    --help, -h    : prints this help and exits

    pathToXSD : path to XML schema. If none, it is derived from pathToXML
    pathToXML : path to XML file.
EOF
exit $1
}
#
# main
#
while [ $# -gt 0 ]; do
  case $1 in
  --help|-h)
    usage 0
    ;;
  --show|-s)
    show=true
    ;;
  *)
    if [ "z$xsd" = "z" ] ; then
        xsd="$1"
    elif [ "z$xml" = "z" ] ; then
        xml="$1"
    fi
    ;;
  esac
  shift
done

[ ! -n "$xsd" ] && {
    echoerr 2 "Fichier XML absent"
}

[ ! -n "$xml" ] && {
    xml=$xsd
    xsd="${xml%xml}xsd"
    [ ! -e $xsd ] && {
        # no xsd found
        unset xsd
    }
}
[ ! -e $xml ] && {
    echoerr 3 "Fichier ${xml} absent"
}
cmdToExec="xmllint --noout"
[ ! -z "$xsd" ] && {
    cmdToExec="${cmdToExec} --schema ${xsd}"
}
cmdToExec="${cmdToExec} ${xml}"
run 100 "${cmdToExec}"

exit 0
