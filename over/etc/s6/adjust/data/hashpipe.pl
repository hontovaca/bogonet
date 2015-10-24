#!/usr/bin/miniperl -w
use 5.016;

my $id = $ENV{id};

$ENV{hash} =~ /^([0-9a-f]{8})/i;
my $dec = hex($1) % (1<<22) + (100<<24) + (64<<16);
my $ip = sprintf "%d.%d.%d.%d", map { ($dec >> $_) & 255 } 24, 16, 8, 0;

say "$id => $ip";

chroot "/mnt";
chdir "/";
exec "pipework", "docker0", $id, "$ip/32";
