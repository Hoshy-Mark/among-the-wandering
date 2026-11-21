extends RefCounted
static func enabled()->bool:
 for arg in OS.get_cmdline_user_args():
  if str(arg).begins_with("--qa") or str(arg).begins_with("--capture") or str(arg).ends_with("-test"):
   if arg=="--map117-test":return true
   return false
 return true
