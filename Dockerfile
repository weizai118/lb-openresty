FROM goodrainapps/alpine:3.4

ADD /openresty.tar.gz /usr/local/

ENV VERSION=__RELEASE_DESC__

ENV OPENRESTY_HOME=/usr/local/openresty \
    HTTP_SUFFIX_URL=rainbond.goodrain.local

WORKDIR $OPENRESTY_HOME

COPY /conf $OPENRESTY_HOME/nginx/conf
COPY /lua $OPENRESTY_HOME/nginx/lua
COPY /bootstrap.sh /bootstrap.sh

COPY /bin /usr/local/bin

RUN chmod +x /usr/local/bin/vrrpd

ENTRYPOINT ["/bootstrap.sh"]