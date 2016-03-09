#!/usr/bin/luajit

local ffi = require 'ffi'
local json = require 'json'
local posix = require 'posix'

setmetatable(_G, {__index = function (t,k) error("global: " .. k, 2) end})

ffi.cdef[[
char **environ;
int chroot(const char *);
int chdir(const char *);
int crypto_hash_sha256(unsigned char *out, const unsigned char *in, unsigned long long inlen);
]]

local sodium = ffi.load 'sodium'

ffi.C.environ[0] = nil
posix.setenv("PATH",
"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/bin")

assert(ffi.C.chroot("/mnt") >= 0, "failed to chroot")
assert(ffi.C.chdir("/")     >= 0, "failed to chdir")

local function retrieve(...)
  local r,w = posix.pipe()
  local pid = posix.fork()
  if pid > 0 then
    posix.close(w)
    local s = ""
    while true do
      local buf = posix.read(r, 4096)
      if not buf or #buf <= 0 then
        break
      end
      s = s .. buf
    end
    posix.close(r)
    posix.wait(pid)
    return s
  else
    posix.dup2(w, 1)
    posix.close(r)
    posix.close(w)
    posix.execp("docker", {"inspect", ...})
    error "failed to exec"
  end
end

local function assign(...)
  local res = json.decode(retrieve(...))
  for i,s in ipairs(res) do
    local cid = s.Id:sub(1,12)
    local key = s.Config.Hostname

    if s.HostConfig.NetworkMode == "default" then
      local out = ffi.new("unsigned char[32]")
      sodium.crypto_hash_sha256(out, key, #key)
      local hash = bit.tohex(ffi.cast("uint32_t *", out)[0])
      out[0] = bit.band(out[0], 63)
      local addr = table.concat({100, 64+out[0], out[1], out[2]}, ".")
      print(("%s %s: %s (%s)"):format(cid, key, addr, hash))

      local pid = posix.fork()
      if pid > 0 then
        posix.wait(pid)
      else
        posix.execp("pipework", {"docker0", s.Id, addr .. "/32"})
      end
    else
      print(("%s %s: skipping, not net=default"):format(cid, key))
    end
  end
end

do
  local pid = posix.fork()
  if pid > 0 then
    posix.wait(pid)
  else
    posix.execp("ip", "addr", "replace", "100.64.36.16/10", "dev", "docker0")
  end
end

io.stdin:setvbuf 'line'
io.stdout:setvbuf 'line'
for raw in io.lines() do
  local event = json.decode(raw)

  if #event > 0 then
    for i,s in ipairs(event) do
      event[i] = s.Id
    end
    assign(unpack(event))
  else
    if event.status == "start" then
      assign(event.id)
    end
  end
end
