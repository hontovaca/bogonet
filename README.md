## bogonet: amazingly stupid service uncovery

Most of the time, if you want to give a service a name, you want to give it a
name you might actually remember, like a hostname. Or maybe you don't really
care what name it gets, as long as you can refer to it as part of a group.

If you're like me, you might just not care and just want a consistent address
for a container that'll stay the same over restarts and reboots. Maybe even
survive container destruction and recreation, but that might be a bit much.

bogonet tries to assign a consistent IP address to each container as it starts.
It doesn't expose a nice interface or anything, it won't do service discovery
or anything; that would require guessing what you call your services, which is
hard. It just assigns random IPs from the carrier-grade NAT space in its own
stupid, opinionated way. I guess you can name them yourself however you want?
