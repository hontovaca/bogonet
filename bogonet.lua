#!/usr/bin/luajit
local ffi = require 'ffi'
local json = require 'json'
setmetatable(_G, {__index = function (t,k) error("global: " .. k, 2) end})

ffi.cdef[[
/* for chroot */
char **environ;
int setenv(const char *, const char *, int);
int chroot(const char *);
int chdir(const char *);

/* for pipe-fork-dup-exec */
int pipe(int[2]);
int fork(void);
int wait(int *);
int dup2(int, int);
int close(int);
/* technically wrong, but have luajit do the coercion */
int execvp(const char *, const char *[]);
/* wrong, but fudge it for luajit 2.0; this is true on musl */
typedef size_t ssize_t;
ssize_t read(int, void *, size_t);

int crypto_hash_sha256(unsigned char *, const unsigned char *, unsigned long long);
]]

local sodium = ffi.load 'sodium'

local function pipe()
  local out = ffi.new "int[2]"
  ffi.C.pipe(out)
  return out[0], out[1]
end

local function wait()
  local stat_loc = ffi.new "int[1]"
  return ffi.C.wait(stat_loc), stat_loc[0]
end

local function execvp(s, t, ...)
  if type(s) == "table" then
    return execvp(s[1], s)
  elseif type(t) ~= "table" then
    return execvp(s, {s, t, ...})
  end

  local size = #t
  local argv = ffi.new("const char *[?]", size+1, t)
  argv[size] = nil

  ffi.C.execvp(s, argv)
  error("failed to exec " .. s .. ": " .. ffi.errno())
end

local function read(fd)
  local got = {}
  local res
  while res ~= 0 do
    local buf = ffi.new "char[4001]"
    res = ffi.C.read(fd, buf, 4000)
    got[#got+1] = ffi.string(buf)
  end
  return table.concat(got)
end

local function chroot_host()
  ffi.C.environ[0] = nil
  ffi.C.setenv("PATH", table.concat({
    "/usr/local/sbin",
    "/usr/local/bin",
    "/usr/sbin",
    "/usr/bin",
    "/sbin",
    "/bin",
    "/opt/bin"
  }, ":"), 0)
  assert(ffi.C.chroot("/mnt") >= 0, "failed to chroot")
  assert(ffi.C.chdir("/")     >= 0, "failed to chdir")
end

local function reconnect_output()
  local r,w = pipe()
  local pid = ffi.C.fork()

  if pid == 0 then
    ffi.C.dup2(r, 0)
    ffi.C.close(r)
    ffi.C.close(w)

    for line in io.lines() do
      print(os.date("%F %T\t", os.time()) .. line)
    end
  end

  ffi.C.dup2(w, 1)
  ffi.C.dup2(w, 2)
  ffi.C.close(r)
  ffi.C.close(w)
  io.stdout:setvbuf 'line'
  io.stderr:setvbuf 'line'
end

local function reconnect_input()
  local r,w = pipe()
  local pid = ffi.C.fork()

  if pid == 0 then
    ffi.C.dup2(w, 1)
    ffi.C.close(r)
    ffi.C.close(w)
    execvp{
      "curl", "--no-buffer", "--silent", "--show-error",
      "--unix-socket", "/var/run/docker.sock",
      "0/v1.20/containers/json",
      "0/v1.20/events"
    }
  end

  ffi.C.dup2(r, 0)
  ffi.C.close(r)
  ffi.C.close(w)
  io.stdin:setvbuf 'line'
end

local function set_ip()
  local pid = ffi.C.fork()
  if pid == 0 then
    execvp("ip", "addr", "replace", "100.64.36.16/10", "dev", "docker0")
  end

  wait(pid)
end

local function docker_inspect(...)
  local r,w = pipe()
  local pid = ffi.C.fork()

  if pid == 0 then
    ffi.C.dup2(w, 1)
    ffi.C.close(r)
    ffi.C.close(w)
    execvp("docker", "inspect", ...)
    error "failed to exec"
  end

  ffi.C.close(w)
  local s = read(r)
  ffi.C.close(r)
  wait(pid)
  return s
end

local function assign_ip(...)
  local res = json.decode(docker_inspect(...))
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

      local pid = ffi.C.fork()
      if pid > 0 then
        wait(pid)
      else
        execvp("pipework", "docker0", s.Id, addr .. "/32")
      end
    else
      print(("%s %s: skipping, not net=default"):format(cid, key))
    end
  end
end

reconnect_output()
chroot_host()
set_ip()
reconnect_input()
print "bogonet up"

for raw in io.lines() do
  local event = json.decode(raw)

  if #event > 0 then
    for i,s in ipairs(event) do
      event[i] = s.Id
    end
    assign_ip(unpack(event))
  else
    if event.status == "start" then
      assign_ip(event.id)
    end
  end
end
