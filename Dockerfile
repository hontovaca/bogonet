FROM vaca/rc

RUN apk --no-cache add libsodium-dev lua5.1-json4 lua5.1-posix
COPY over /
