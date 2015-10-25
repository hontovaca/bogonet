FROM vaca/rc

RUN apk -U add ruby && rm -f /var/cache/apk/*
COPY over /
