FROM ubuntu:14.04
MAINTAINER Didier Richard <didier.richard@ign.fr>
RUN \
    apt-get update && \
    apt-get install -yq libxml2-utils
COPY xsdlint.sh /usr/bin/xsdlint.sh
ENTRYPOINT ["xsdlint.sh"]
CMD ["--help"]

