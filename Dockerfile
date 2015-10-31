FROM vaca/rc

RUN apk add -U lua5.1-posix && rm -f /var/cache/apk/*
COPY over /
