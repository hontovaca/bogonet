FROM vaca/rc

RUN apk --no-cache add lua5.1-filesystem lua5.1-json4 lua5.1-posix
COPY over /
