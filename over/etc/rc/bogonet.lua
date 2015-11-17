rc:merge {
  notify = {
    type = "longrun",
    producer_for = "adjust",
    run = realign [[
    #!/bin/execlineb -P
    chroot /mnt
    curl -NsS --unix-socket /var/run/docker.sock
    0/v1.20/containers/json
    0/v1.20/events
    ]]
  },

  adjust = {
    type = "longrun",
    consumer_for = "notify",
    run = file_slurp "bogonet/adjust.lua",
    data = {
      ["sha256.lua"] = file_slurp "bogonet/sha256/sha256.lua"
    }
  },

  [3] = { contents = "notify" },
}
