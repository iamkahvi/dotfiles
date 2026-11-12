#!/usr/bin/env python3
"""Display an image in a Kitty-compatible terminal. Press Enter to finish."""

import argparse
import base64
import fcntl
import os
import re
import select
import signal
import struct
import subprocess
import sys
import termios
import time
import tty
from pathlib import Path

PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'
DA = re.compile(rb'\x1b\[\?[0-9;]*c')
IMAGE_ID = 424243


def image_data(path):
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        data = subprocess.run(
            ['magick', str(path) + '[0]', '-strip', 'PNG:-'],
            check=True, stdout=subprocess.PIPE,
        ).stdout
    if len(data) < 24 or not data.startswith(PNG_SIGNATURE) or data[12:16] != b'IHDR':
        raise ValueError('Input is not a valid PNG')
    width, height = struct.unpack('>II', data[16:24])
    if not width or not height:
        raise ValueError('Image dimensions must be positive')
    return base64.b64encode(data), width, height


def send(fd, data):
    remaining = memoryview(data)
    while remaining:
        remaining = remaining[os.write(fd, remaining):]


def response(fd):
    data = b''
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        ready, _, _ = select.select([fd], [], [], max(0, deadline - time.monotonic()))
        if not ready:
            break
        data += os.read(fd, 4096)
        if DA.search(data):
            break
    return data


def image_columns(fd, width, height):
    rows, cols, px_width, px_height = struct.unpack(
        'HHHH', fcntl.ioctl(fd, termios.TIOCGWINSZ, b'\0' * 8)
    )
    rows, cols = rows or 24, cols or 80
    cell_width = px_width / cols if px_width else 8
    cell_height = px_height / rows if px_height else 16
    fit = int(max(1, rows - 4) * cell_height * width / height / cell_width)
    return max(1, min(cols - 1, fit))


def draw(fd, encoded, width, height):
    columns = image_columns(fd, width, height)
    send(fd, f'\x1b_Ga=d,d=I,i={IMAGE_ID}\x1b\\\x1b[2J\x1b[H'.encode())
    for offset in range(0, len(encoded), 4096):
        part = encoded[offset:offset + 4096]
        more = int(offset + len(part) < len(encoded))
        controls = (f'a=T,f=100,i={IMAGE_ID},c={columns},m={more}'
                    if offset == 0 else f'm={more}')
        send(fd, b'\x1b_G' + controls.encode() + b';' + part + b'\x1b\\')
    send(fd, b'\x1b[c')
    reply = response(fd)
    if f'\x1b_Gi={IMAGE_ID};OK\x1b\\'.encode() not in reply:
        raise RuntimeError(f'Image was not accepted: {reply!r}')
    send(fd, b'\r\nImage accepted. Press Enter to finish.\r\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('image', type=Path)
    parser.add_argument('--once', action='store_true', help='exit after the first draw')
    args = parser.parse_args()
    encoded, width, height = image_data(args.image)
    fd = os.open('/dev/tty', os.O_RDWR)
    old = termios.tcgetattr(fd)
    resized = False

    def on_resize(_signum, _frame):
        nonlocal resized
        resized = True

    previous_handler = signal.signal(signal.SIGWINCH, on_resize)
    try:
        tty.setraw(fd)
        time.sleep(0.5)  # Allow the app to set the pane size.
        send(fd, b'\x1b_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA\x1b\\\x1b[c')
        reply = response(fd)
        if b'\x1b_Gi=31;OK\x1b\\' not in reply:
            raise RuntimeError(f'Kitty graphics query failed: {reply!r}')
        resized = False
        draw(fd, encoded, width, height)
        if args.once:
            return
        while True:
            ready, _, _ = select.select([fd], [], [], 0.5)
            if ready:
                keys = os.read(fd, 4096)
                if any(key in keys for key in (b'\r', b'\n', b'\x03')):
                    break
            if resized:
                resized = False
                draw(fd, encoded, width, height)
    finally:
        signal.signal(signal.SIGWINCH, previous_handler)
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
        os.close(fd)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f'rex-diagram: {error}', file=sys.stderr)
        sys.exit(1)
