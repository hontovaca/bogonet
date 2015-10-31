FROM vaca/rc

RUN apk add -U ruby-irb && rm -f /var/cache/apk/*
COPY over /
