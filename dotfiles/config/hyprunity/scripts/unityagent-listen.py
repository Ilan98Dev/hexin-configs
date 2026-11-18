#!/usr/bin/env python3
"""Hold a FIFO open and print every line written to it.

`cat` is not good enough here: it blocks in open() until a writer appears, so a
non-blocking writer (O_WRONLY|O_NONBLOCK) fails with ENXIO. Opening the FIFO
O_RDWR keeps both ends alive for the lifetime of this process, so writers never
block and never fail, and Quickshell gets a steady stream on stdout.

A FIFO delivers each line to exactly one reader, so a second reader (a leftover
from an earlier shell generation) would silently steal half the messages. This
script therefore evicts any other process reading the same FIFO, and dies with
its parent (so closing the shell never leaves an orphan behind).
"""

import os
import select
import signal
import sys

FIFO = sys.argv[1] if len(sys.argv) > 1 else "/tmp/unityagent_ipc.fifo"
SELF_EXE = os.path.basename(__file__)
DAEMON = "unityagentd"


def die_with_parent():
    try:
        import ctypes

        libc = ctypes.CDLL("libc.so.6", use_errno=True)
        libc.prctl(1, signal.SIGTERM, 0, 0, 0)  # PR_SET_PDEATHSIG
    except Exception:
        pass
    if os.getppid() == 1:
        sys.exit(0)


def evict_other_readers():
    """Kill every other process that has this FIFO open for reading."""
    me = os.getpid()
    for entry in os.listdir("/proc"):
        if not entry.isdigit() or int(entry) == me:
            continue
        pid = int(entry)
        try:
            with open("/proc/%d/cmdline" % pid, "rb") as f:
                cmdline = f.read().replace(b"\0", b" ").decode("utf-8", "replace")
        except OSError:
            continue
        if DAEMON in cmdline:
            continue
        try:
            fds = os.listdir("/proc/%d/fd" % pid)
        except OSError:
            continue
        for fd in fds:
            try:
                if os.readlink("/proc/%d/fd/%s" % (pid, fd)) != FIFO:
                    continue
            except OSError:
                continue
            try:
                os.kill(pid, signal.SIGTERM)
                sys.stderr.write("unityagent-listen: evicted stale reader pid %d\n" % pid)
            except OSError:
                pass
            break


def main():
    die_with_parent()
    evict_other_readers()

    fd = os.open(FIFO, os.O_RDWR | os.O_NONBLOCK)

    buf = b""
    while True:
        try:
            ready, _, _ = select.select([fd], [], [], None)
        except InterruptedError:
            continue
        if not ready:
            continue
        try:
            chunk = os.read(fd, 4096)
        except BlockingIOError:
            continue
        except OSError:
            break
        if not chunk:
            continue
        buf += chunk
        while b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            sys.stdout.write(line.decode("utf-8", "replace") + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
