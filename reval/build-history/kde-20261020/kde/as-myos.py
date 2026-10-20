import os
import pwd
import sys

if os.geteuid() != 0:
    raise SystemExit("Помощник запускается основным сценарием от root.")
if len(sys.argv) < 2:
    raise SystemExit("Не указана команда.")

account = pwd.getpwnam("myos")
environment = {
    "HOME": account.pw_dir,
    "USER": account.pw_name,
    "LOGNAME": account.pw_name,
    "SHELL": account.pw_shell,
    "PATH": "/opt/qt6/bin:/usr/local/bin:/usr/bin:/bin",
    "QT6DIR": "/opt/qt6",
    "CMAKE_PREFIX_PATH": "/opt/qt6",
    "PKG_CONFIG_PATH": "/opt/qt6/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig",
    "LANG": os.environ.get("LANG", "C.UTF-8"),
    "TERM": os.environ.get("TERM", "xterm"),
}

os.initgroups(account.pw_name, account.pw_gid)
os.setgid(account.pw_gid)
os.setuid(account.pw_uid)
os.chdir("/home/myos/reval-build/kde/frameworks-6.29.0")
os.execvpe(sys.argv[1], sys.argv[1:], environment)
