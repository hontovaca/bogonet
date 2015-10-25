## bogonet: amazingly stupid service uncovery

Most of the time, if you want to give a service a name, you want to give it a name you might actually remember, like a hostname. Or maybe you don't really care what name it gets, as long as you can refer to it as part of a group.

If you're like me, you might just not care and just want a consistent address for a container that'll stay the same over restarts and reboots. Maybe even survive container destruction and recreation, but that might be a bit much.

bogonet tries to assign a consistent IP address to each container as it starts. It doesn't expose a nice interface or anything, it won't do service discovery or anything; that would require guessing what you call your services, which is hard. It just assigns random IPs from the carrier-grade NAT space in its own stupid, opinionated way. I guess you can name them yourself however you want?

### Carrier-grade NAT?

So it turns out, if you randomly assign unique identifiers, you start getting collisions p fast. Start with a /24 block, you have better than even odds of a collision by container #20. Start with a /16 block, and you support maybe 300.

That's good enough, probably, but then we'd have to choose the block, and it takes a bit of effort to choose one of the blocks allocated for private use that isn't already used by *someone* for *something*.

bogonet doesn't do effort. It just so happens that there's a whole /10 block set aside for carrier-grade NAT, and, if you're anything like me, you do not keep your servers behind carrier-grade NAT. It's not a block that's likely to be used for anything, not least because you're not *supposed* to use it except on service provider networks and routing equipment.

... but you know, if you think about it a certain way, the container host is kind of a router, so it's justifiable, right? And if nobody else is using it on your network, it probably won't break anything ...

### Details, details

bogonet requires the host mounted at /mnt (read-only is fine), with docker and pipework installed to discoverable locations (PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/bin). It also depends on iproute, but so does pipework.

The IP address assigned to any given container is dependent on bits 232-253 (i.e. high 24b, except the highest 2b) of the SHA256 hash of the container's *hostname*; note that this requires the containers to have distinct hostnames; this is usually not an issue (they're assigned random hostnames unless you specify one anyway), but it is the single means provided for ensuring you get a known IP address. Both the hostname and the high 24 bits (and the resulting address) are logged. The hashing does mean it's easier to compute the result than it is to pick a hostname for the address you prefer, but the address space is only 22 bits, so you can brute-force that in under a minute; it's for avoiding accidental collisions, not a defense against preimaging.

bogosort just skips --net=host containers, mostly because it breaks things and secondarily because that just doesn't make sense.
