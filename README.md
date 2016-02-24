% Mini-projet : Exécuter un validateur XML au sein d'un containeur
% Didier Richard
% rèv. 0.0.1 du 31/01/2016

---

# Use docker to validate an XML file #

The objective is to check whether an XML file is well formed and validates
against a given schema.

In order to build to docker images, we start by writing the shell that checks
the XML/XSD files. Let's call it `xsdlint.sh`.
Once `xsdlint.sh` is tested, we write the `Dockerfile` and then build the images.
Finally, we test the image under multiple use case :

* no arguments given : check that --help is passed to `xsdlint.sh` ;
* give path to files and xml file : check that the validation is done ;
* don't give path to files : check that validation raises an error !

## The XML/XSD script linter ##

The shortest path to write such a linter is to use `xmllint` from the
`libxml2` project. We assume that `libxml2-utils` is installed in the host (or
any ubuntu 14.04 VM).

The `xsdlint.sh` looks like :

```bash
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
```

We can test it :

* no parameters are given :

```bash
$ ./xsdlint.sh
Fichier XML absent
usage: xsdlint.sh [--help -h] | [pathToXSD] pathToXML

    --help, -h    : prints this help and exits

    pathToXSD : path to XML schema. If none, it is derived from pathToXML
    pathToXML : path to XML file.
```

* option `--help` :

```bash
$ ./xsdlint.sh --help
usage: xsdlint.sh [--help -h] | [pathToXSD] pathToXML

    --help, -h    : prints this help and exits

    pathToXSD : path to XML schema. If none, it is derived from pathToXML
    pathToXML : path to XML file.
```

* with an XML file that does not exist :

```bash
$ ./xsdlint.sh oops.xml
Fichier oops.xml absent
usage: xsdlint.sh [--help -h] | [pathToXSD] pathToXML

    --help, -h    : prints this help and exits

    pathToXSD : path to XML schema. If none, it is derived from pathToXML
    pathToXML : path to XML file.
```

* with an XML file that dost exist, but not the XSD schema, checks what is
  done :

```bash
$ ./xsdlint.sh --show ok.xml 
cmd: xmllint --noout ok.xml
```

* with an XML file and its XSD schema, schema what is done :

```bash
$ ./xsdlint.sh --show /data/git/xml2-a/exos/stagiaires.xml
cmd: xmllint --noout --schema /data/git/xml2-a/exos/stagiaires.xsd /data/git/xml2-a/exos/stagiaires.xml
```

* same test, but now run the validation :

```bash
$ ./xsdlint.sh /data/git/xml2-a/exos/stagiaires.xml
/data/git/xml2-a/exos/stagiaires.xml validates
```

* same test, but now give the XSD file explicitely :
```bash
$ ./xsdlint.sh stagiaires.xsd /data/git/xml2-a/exos/stagiaires.xml
/data/git/xml2-a/exos/stagiaires.xml validates
```

## Create the docker image ##

The `Dockerfile` is based on alpine:3.3. It installs the `bash` and
`libxml2-utils` packages, then copy the `xsdlint.sh` shell script into the
image. It also defined the default command as `xsdlint.sh` and, when no
arguments are given to the container (at the run stage), it passes in the
`--help` option to the default command. The file is then as follows :

```text
FROM alpine:3.3
MAINTAINER Didier Richard <didier.richard@ign.fr>
RUN \
    apk update && \
    apk add --no-cache --update-cache bash libxml2-utils && \
    rm -rf /var/cache/apk/*
COPY xsdlint.sh /usr/bin/xsdlint.sh
ENTRYPOINT ["xsdlint.sh"]
CMD ["--help"]
```

Let's run it and build a versionned image, also taggued latest :

```bash
$ docker build -t dgricci/xmllint:0.0.1 -t dgricci/xmllint:latest .
Sending build context to Docker daemon 39.42 kB
Step 1 : FROM alpine:3.3
 ---> 0d81fc72e790
Step 2 : MAINTAINER Didier Richard <didier.richard@ign.fr>
 ---> Running in d34f3b2f1de2
 ---> 2eac89ad17d0
Removing intermediate container d34f3b2f1de2
Step 3 : RUN apk update &&     apk add --no-cache --update-cache bash libxml2-utils &&     rm -rf /var/cache/apk/*
 ---> Running in d5f49af5211f
fetch http://dl-4.alpinelinux.org/alpine/v3.3/main/x86_64/APKINDEX.tar.gz
fetch http://dl-4.alpinelinux.org/alpine/v3.3/community/x86_64/APKINDEX.tar.gz
v3.3.1-79-gd691e49 [http://dl-4.alpinelinux.org/alpine/v3.3/main]
v3.3.1-59-g48b0368 [http://dl-4.alpinelinux.org/alpine/v3.3/community]
OK: 5859 distinct packages available
fetch http://dl-4.alpinelinux.org/alpine/v3.3/main/x86_64/APKINDEX.tar.gz
fetch http://dl-4.alpinelinux.org/alpine/v3.3/main/x86_64/APKINDEX.tar.gz
fetch http://dl-4.alpinelinux.org/alpine/v3.3/community/x86_64/APKINDEX.tar.gz
fetch http://dl-4.alpinelinux.org/alpine/v3.3/community/x86_64/APKINDEX.tar.gz
(1/7) Installing ncurses-terminfo-base (6.0-r6)
(2/7) Installing ncurses-terminfo (6.0-r6)
(3/7) Installing ncurses-libs (6.0-r6)
(4/7) Installing readline (6.3.008-r4)
(5/7) Installing bash (4.3.42-r3)
Executing bash-4.3.42-r3.post-install
(6/7) Installing libxml2 (2.9.3-r0)
(7/7) Installing libxml2-utils (2.9.3-r0)
Executing busybox-1.24.1-r7.trigger
OK: 14 MiB in 18 packages
 ---> f82916b86628
Removing intermediate container d5f49af5211f
Step 4 : COPY xsdlint.sh /usr/bin/xsdlint.sh
 ---> 865bf12c576f
Removing intermediate container c5ebe419f6da
Step 5 : ENTRYPOINT xsdlint.sh
 ---> Running in 5c8edcbae4f2
 ---> caa3009adbe8
Removing intermediate container 5c8edcbae4f2
Step 6 : CMD --help
 ---> Running in fd8cae33e9fb
 ---> 120adefa82ab
Removing intermediate container fd8cae33e9fb
Successfully built 120adefa82ab
```

Let's check the images first :

```bash
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED VIRTUAL     SIZE
dgricci/xmllint     0.0.1               120adefa82ab        49 seconds ago      9.795 MB
dgricci/xmllint     latest              120adefa82ab        49 seconds ago      9.795 MB
...
```

## Run the image ##

* no arguments, check `--help` is passed in :

```bash
$ docker run --rm dgricci/xmllint
usage: xsdlint.sh [--help -h] | [pathToXSD] pathToXML

    --help, -h    : prints this help and exits

    pathToXSD : path to XML schema. If none, it is derived from pathToXML
    pathToXML : path to XML file.
```

* mount path to xml and checks :

```bash
$ docker run --rm -v /data:/data:ro dgricci/xmllint /data/git/xml2-a/exos/stagiaires.xml
/data/git/xml2-a/exos/stagiaires.xml validates
```

* same, but verify what is done :

```bash
$ docker run --rm -v /data:/data:ro dgricci/xmllint --show /data/git/xml2-a/exos/stagiaires.xml
cmd: xmllint --noout --schema /data/git/xml2-a/exos/stagiaires.xsd /data/git/xml2-a/exos/stagiaires.xml
```

* now with a non-existing XML file :

```bash
$ docker run --rm -v /data:/data:ro dgricci/xmllint /data/git/xml2-a/exos/oops.xml
Fichier /data/git/xml2-a/exos/oops.xml absent
usage: xsdlint.sh [--help -h] | [pathToXSD] pathToXML

    --help, -h    : prints this help and exits

    pathToXSD : path to XML schema. If none, it is derived from pathToXML
    pathToXML : path to XML file.
```

__Et voilà !__


_fin du document[^pandoc_gen]_

[^pandoc_gen]: document généré via $ `pandoc -V fontsize=10pt -V geometry:"top=2cm, bottom=2cm, left=1cm, right=1cm" -s -N --toc -o xmllint.pdf README.md`{.bash}

