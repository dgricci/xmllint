FROM alpine:3.3
MAINTAINER Didier Richard <didier.richard@ign.fr>
RUN \
    apk update && \
    apk add --no-cache --update-cache bash libxml2-utils && \
    rm -rf /var/cache/apk/*
COPY xsdlint.sh /usr/bin/xsdlint.sh
ENTRYPOINT ["xsdlint.sh"]
CMD ["--help"]

