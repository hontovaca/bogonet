#!/usr/bin/luajit

local ffi = require 'ffi'
local lfs = require 'lfs'
local lyaml = require 'lyaml'
local posix = require 'posix'
local sha256 = require 'data/sha256'

setmetatable(_G, {__index = function (t,k) error("global: " .. k) end})

ffi.cdef "char **environ"
ffi.C.environ[0] = nil
posix.setenv("PATH",
"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/bin")

ffi.cdef "int chroot(const char *)"
assert(ffi.C.chroot("/mnt") >= 0, "failed to chroot")
lfs.chdir "/"

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
  local res = lyaml.load(retrieve(...))
  for i,s in ipairs(res) do
    local cid = s.Id:sub(1,12)
    local key = s.Config.Hostname

    if s.HostConfig.NetworkMode == "default" then
      local hash = sha256.hex(key):sub(1,6)
      local part = tonumber(hash, 16) % 0x400000 + 0x64400000
      local dots = {}
      for i=1,4 do
        dots[5-i] = part % 256
        part = (part - dots[5-i]) / 256
      end
      local addr = ("%d.%d.%d.%d"):format(unpack(dots))
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

io.stdin:setvbuf 'line'
io.stdout:setvbuf 'line'
for raw in io.lines() do
  local event = lyaml.load(raw)

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
