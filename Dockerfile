FROM vaca/rc

RUN apk -U add jq && rm -f /var/cache/apk/*
COPY over /
