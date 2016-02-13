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

* no arguments given : check that `--help` is passed to `xsdlint.sh` ;
* give path to files and xml file : check that the validation is done ;
* don't give path to files : check that validation raises an error !

## The XML/XSD script linter ##

The shortest path to write such a linter is to use `xmllint` from the
`libxml2` project.

### Building the solution via docker ###

We can assume that `libxml2-utils` is installed in the host (or
any ubuntu 14.04 VM), but one can also develop the solution within a
container :

```bash
$ cd /data/git/xmllint
$ docker run -it -v `pwd`:/home/xmllint ubuntu:14.04
root@2a6f4018b8af:/# apt-get update
...
root@2a6f4018b8af:/# apt-get install libxml2-utils
...
root@2a6f4018b8af:/# cd /home/xmllint
root@2a6f4018b8af:/home/xmllint# vi xsdlint.sh
...
root@2a6f4018b8af:/home/xmllint# ./xsdlint.sh --help
...
root@2a6f4018b8af:/home/xmllint# exit
```

Thus without "poluting" the host, one can directly prototype and test the
different layers of the up-coming Dockerfile and also the script (which is
shared between the container and the host - thanks to `-v` flag - !

### The bourne again shell script ###

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

### Unitary test ###

We can now test it (either one the host or into the container) :

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

The `Dockerfile` is based on `ubuntu:14.04`. It installs the `libxml2-utils`
package, then copy the `xsdlint.sh` shell script into the image. It also
defined the default command as `xsdlint.sh` and, when no arguments are given
to the container (at the run stage), it passes in the `--help` option to the
default command. The file is then as follows :

```text
FROM ubuntu:14.04
MAINTAINER Didier Richard <didier.richard@ign.fr>
RUN \
    apt-get update && \
    apt-get install -yq libxml2-utils
COPY xsdlint.sh /usr/bin/xsdlint.sh
ENTRYPOINT ["xsdlint.sh"]
CMD ["--help"]
```

Let's run it :

```bash
$ docker build -t dgricci/xmllint:0.0.1 .
Sending build context to Docker daemon 10.24 kB
Step 1 : FROM ubuntu:14.04
 ---> 89d5d8e8bafb
Step 2 : MAINTAINER Didier Richard <didier.richard@ign.fr>
 ---> Running in 99d028446d7d
 ---> ccfa519da80e
Removing intermediate container 99d028446d7d
Step 3 : RUN apt-get update &&     apt-get install -yq libxml2-utils
 ---> Running in 30ed41070c62
Ign http://archive.ubuntu.com trusty InRelease
Get:1 http://archive.ubuntu.com trusty-updates InRelease [64.4 kB]
Get:2 http://archive.ubuntu.com trusty-security InRelease [64.4 kB]
Hit http://archive.ubuntu.com trusty Release.gpg
Hit http://archive.ubuntu.com trusty Release
Get:3 http://archive.ubuntu.com trusty-updates/main Sources [311 kB]
Get:4 http://archive.ubuntu.com trusty-updates/restricted Sources [5219 B]
Get:5 http://archive.ubuntu.com trusty-updates/universe Sources [185 kB]
Get:6 http://archive.ubuntu.com trusty-updates/main amd64 Packages [865 kB]
Get:7 http://archive.ubuntu.com trusty-updates/restricted amd64 Packages [23.4 kB]
Get:8 http://archive.ubuntu.com trusty-updates/universe amd64 Packages [434 kB]
Get:9 http://archive.ubuntu.com trusty-security/main Sources [129 kB]
Get:10 http://archive.ubuntu.com trusty-security/restricted Sources [3920 B]
Get:11 http://archive.ubuntu.com trusty-security/universe Sources [37.9 kB]
Get:12 http://archive.ubuntu.com trusty-security/main amd64 Packages [509 kB]
Get:13 http://archive.ubuntu.com trusty-security/restricted amd64 Packages [20.2 kB]
Get:14 http://archive.ubuntu.com trusty-security/universe amd64 Packages [160 kB]
Get:15 http://archive.ubuntu.com trusty/main Sources [1335 kB]
Get:16 http://archive.ubuntu.com trusty/restricted Sources [5335 B]
Get:17 http://archive.ubuntu.com trusty/universe Sources [7926 kB]
Get:18 http://archive.ubuntu.com trusty/main amd64 Packages [1743 kB]
Get:19 http://archive.ubuntu.com trusty/restricted amd64 Packages [16.0 kB]
Get:20 http://archive.ubuntu.com trusty/universe amd64 Packages [7589 kB]
Fetched 21.4 MB in 27s (779 kB/s)
Reading package lists...
Reading package lists...
Building dependency tree...
Reading state information...
The following extra packages will be installed:
  libxml2 sgml-base xml-core
Suggested packages:
  sgml-base-doc debhelper
The following NEW packages will be installed:
  libxml2 libxml2-utils sgml-base xml-core
0 upgraded, 4 newly installed, 0 to remove and 13 not upgraded.
Need to get 642 kB of archives.
After this operation, 2345 kB of additional disk space will be used.
Get:1 http://archive.ubuntu.com/ubuntu/ trusty-updates/main libxml2 amd64 2.9.1+dfsg1-3ubuntu4.7 [571 kB]
Get:2 http://archive.ubuntu.com/ubuntu/ trusty/main sgml-base all 1.26+nmu4ubuntu1 [12.5 kB]
Get:3 http://archive.ubuntu.com/ubuntu/ trusty/main xml-core all 0.13+nmu2 [23.3 kB]
Get:4 http://archive.ubuntu.com/ubuntu/ trusty-updates/main libxml2-utils amd64 2.9.1+dfsg1-3ubuntu4.7 [34.7 kB]
debconf: unable to initialize frontend: Dialog
debconf: (TERM is not set, so the dialog frontend is not usable.)                                                                                      
debconf: falling back to frontend: Readline
debconf: unable to initialize frontend: Readline
debconf: (This frontend requires a controlling tty.)
debconf: falling back to frontend: Teletype
dpkg-preconfigure: unable to re-open stdin: 
Fetched 642 kB in 1s (558 kB/s)
Selecting previously unselected package libxml2:amd64.
(Reading database ... 11542 files and directories currently installed.)
Preparing to unpack .../libxml2_2.9.1+dfsg1-3ubuntu4.7_amd64.deb ...
Unpacking libxml2:amd64 (2.9.1+dfsg1-3ubuntu4.7) ...
Selecting previously unselected package sgml-base.
Preparing to unpack .../sgml-base_1.26+nmu4ubuntu1_all.deb ...
Unpacking sgml-base (1.26+nmu4ubuntu1) ...
Selecting previously unselected package xml-core.
Preparing to unpack .../xml-core_0.13+nmu2_all.deb ...
Unpacking xml-core (0.13+nmu2) ...
Selecting previously unselected package libxml2-utils.
Preparing to unpack .../libxml2-utils_2.9.1+dfsg1-3ubuntu4.7_amd64.deb ...
Unpacking libxml2-utils (2.9.1+dfsg1-3ubuntu4.7) ...
Setting up libxml2:amd64 (2.9.1+dfsg1-3ubuntu4.7) ...
Setting up sgml-base (1.26+nmu4ubuntu1) ...
Setting up xml-core (0.13+nmu2) ...
Setting up libxml2-utils (2.9.1+dfsg1-3ubuntu4.7) ...
Processing triggers for libc-bin (2.19-0ubuntu6.6) ...
Processing triggers for sgml-base (1.26+nmu4ubuntu1) ...
 ---> b2537c03661f
Removing intermediate container 30ed41070c62
Step 4 : ADD xsdlint.sh /usr/bin/xsdlint.sh
 ---> 4e37a0fc2484
Removing intermediate container cb8ac27462f4
Step 5 : ENTRYPOINT xsdlint.sh
 ---> Running in 034de88f325e
 ---> 495daaa9e953
Removing intermediate container 034de88f325e
Step 6 : CMD --help
 ---> Running in 2cbbf2373abe
 ---> af873920e066
Removing intermediate container 2cbbf2373abe
Successfully built af873920e066
```

Let's also tag it as `latest` :

```bash
$ docker build -t dgricci/xmllint .
Sending build context to Docker daemon 35.84 kB
Step 1 : FROM ubuntu:14.04
 ---> 89d5d8e8bafb
Step 2 : MAINTAINER Didier Richard <didier.richard@ign.fr>
 ---> Using cache
 ---> ccfa519da80e
Step 3 : RUN apt-get update &&     apt-get install -yq libxml2-utils
 ---> Using cache
 ---> b2537c03661f
Step 4 : ADD xsdlint.sh /usr/bin/xsdlint.sh
 ---> Using cache
 ---> 4e37a0fc2484
Step 5 : ENTRYPOINT xsdlint.sh
 ---> Using cache
 ---> 495daaa9e953
Step 6 : CMD --help
 ---> Using cache
 ---> af873920e066
Successfully built af873920e066
```

Let's check the images first :

```bash
$ docker images
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED VIRTUAL  SIZE
dgricci/xmllint     0.0.1               af873920e066        2 minutes ago    212.1 MB
dgricci/xmllint     latest              af873920e066        2 minutes ago    212.1 MB
```

## Run the image for some tests ##

* no arguments, check `--help` is passed in :

```bash
$ docker run dgricci/xmllint
usage: xsdlint.sh [--help -h] | [pathToXSD] pathToXML

    --help, -h    : prints this help and exits

    pathToXSD : path to XML schema. If none, it is derived from pathToXML
    pathToXML : path to XML file.
```

* mount path to xml and checks :

```bash
$ docker run -v /data:/data dgricci/xmllint /data/git/xml2-a/exos/stagiaires.xml
/data/git/xml2-a/exos/stagiaires.xml validates
```

* same, but verify what is done :

```bash
$ docker run -v /data:/data dgricci/xmllint --show /data/git/xml2-a/exos/stagiaires.xml
cmd: xmllint --noout --schema /data/git/xml2-a/exos/stagiaires.xsd /data/git/xml2-a/exos/stagiaires.xml
```

* now with a non-existing XML file :

```bash
$ docker run -v /data:/data dgricci/xmllint /data/git/xml2-a/exos/oops.xml
Fichier /data/git/xml2-a/exos/oops.xml absent
usage: xsdlint.sh [--help -h] | [pathToXSD] pathToXML

    --help, -h    : prints this help and exits

    pathToXSD : path to XML schema. If none, it is derived from pathToXML
    pathToXML : path to XML file.
```

__Et voilà !__


_fin du document[^pandoc_gen]_

[^pandoc_gen]: document généré via $ `pandoc -V fontsize=10pt -V geometry:"top=2cm, bottom=2cm, left=1cm, right=1cm" -s -N --toc -o xmllint.pdf README.md`{.bash}

