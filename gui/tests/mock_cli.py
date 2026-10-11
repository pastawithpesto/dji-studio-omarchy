#!/usr/bin/python3
"""Synthetic transport-only fixture executable; never a production backend."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

source = Path(sys.argv[2] if sys.argv[1] == '--metadata' else sys.argv[1])
mode = source.read_text().strip()
if mode == 'flood':
    os.write(1, b'x' * 1000000 + b'OUTTAIL')
    os.write(2, b'\xff' * 1000000 + b'ERRTAIL')
elif mode == 'nonzero':
    print('real fixture nonzero', file=sys.stderr)
    sys.exit(7)
elif mode == 'crash':
    time.sleep(.1)
    os.kill(os.getpid(), signal.SIGKILL)
elif mode in ('timeout', 'crash-child'):
    child = subprocess.Popen(['/usr/bin/python3', '-c',
        'import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); time.sleep(60)'])
    print('child=' + str(child.pid), flush=True)
    if mode == 'crash-child':
        time.sleep(1)
        os.kill(os.getpid(), signal.SIGKILL)
    time.sleep(60)
elif mode == 'disk-full':
    with open('/dev/full', 'wb', buffering=0) as file:
        file.write(b'controlled fixture')
elif mode == 'identity-change':
    source.write_bytes(b'changed owned synthetic source after snapshot')
elif mode == 'wrong-dimension':
    subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-f', 'lavfi', '-i',
                    'color=c=red:s=32x16:r=1', '-t', '1', '-c:v', 'libx264',
                    '-pix_fmt', 'yuv420p', sys.argv[2]], check=True)
elif sys.argv[1] != '--metadata':
    Path(sys.argv[2]).write_bytes(b'not a media file')
else:
    print('no direct tracks — fixture diagnostic')
