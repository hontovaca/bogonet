FROM vaca/rc

RUN apk add -U lua5.1-filesystem lua5.1-json4 lua5.1-posix && rm -f /var/cache/apk/*
COPY over /
