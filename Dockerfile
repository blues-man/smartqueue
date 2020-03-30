FROM fedora

MAINTAINER Natale Vinto <nvinto@redhat.com>

ENV DEBUG 0
ENV VERBOSE 0

RUN yum update -y && rm -rf /var/cache/yum
RUN yum install -y perl-libwww-perl perl-LWP-Protocol-https perl-Authen-SASL perl-DBD-SQLite perl-DBD-SQLite perl-MIME-Lite perl-JSON-MaybeXS  && yum clean all

RUN mkdir -p /opt/src/
COPY esselunga.pl /opt/src/


RUN chown -R 1001:0 /opt/src && \
    chmod -R g=u /opt/src && \
    chmod +x /opt/src/esselunga.pl

USER 1001

WORKDIR /opt/src
CMD ./esselunga.pl
