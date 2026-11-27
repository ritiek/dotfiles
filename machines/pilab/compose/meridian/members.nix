# Claude Team seats pooled in this Meridian. Each member signs in once as a
# Meridian profile named after them: http://pilab.lion-zebra.ts.net:3456/profiles,
# "Add profile", then they open the link and you paste back their code. With
# MERIDIAN_ROUTING=priority, Meridian fails over between profiles when one runs
# out of quota, in the order set at /settings: put volunteers in it, and leave
# out anyone who doesn't lend their seat.
#
# A member listed here gets virtual key vk-<name> (BIFROST_VK_<NAME> in
# ../bifrost/stack.env). Bifrost pins its Meridian requests to the member's own
# profile, then falls back to the pool. ritiek is not listed: his login is the
# default profile (~/.claude), first in the order, and his machines' keys use
# the pool directly.
[
  # "alice"
]
