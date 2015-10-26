#!/usr/bin/ruby
require 'digest/sha2'
require 'ipaddr'
require 'yaml' # ... json is a subset of yaml

ENV.clear
ENV["PATH"] = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/bin"
$stdout.sync = $stderr.sync = true
YAML.load "" # XXX avoid attempting to look for files after chroot
Dir.chroot "/mnt"
Dir.chdir "/"

def assign(*cids)
  YAML.load(IO.popen(["docker", "inspect", *cids]).read).each do |info|
    cid = info["Id"]
    key = info["Config"]["Hostname"]

    if (mode = info["HostConfig"]["NetworkMode"]) != "default"
      warn "#{cid[0,12]} #{key}: skipping, net=#{mode} not default"
      next
    end

    hash = Digest::SHA2.new.update(key)
    part = hash.hexdigest[0,6].hex % (1 << 22)
    addr = IPAddr.new IPAddr.new("100.64.0.0").to_i + part, Socket::AF_INET

    puts "#{cid[0,12]} #{key}: #{addr} (#{hash.hexdigest[0,6]})"

    system "pipework", "docker0", cid, "#{addr}/32"
  end
end

system "ip", "addr", "replace", "100.64.36.16/10", "dev", "docker0"

ARGF.each_line do |raw|
  event = YAML.load raw

  case event
  when Hash
    event["status"] == "start" or next
    assign event["id"]
  when Array
    assign(*event.map { |e| e["Id"] })
  end
end
