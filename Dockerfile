FROM vaca/apk.static
RUN ["apk.static","--no-cache","--no-progress","add","--upgrade", \
      "luajit", "libsodium-dev", "s6", \
      "lua5.1-json4", "lua5.1-posix"]

COPY ["bogonet.lua", "/usr/local/sbin/bogonet"]
CMD ["bogonet"]
