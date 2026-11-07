#!/usr/bin/env python3
"""Verify an unmodified iOS 16.1.1 HDSViewService binary before trying the tweak."""
import hashlib
import sys
from pathlib import Path

SHA256 = '0ef19ac608379b89fc0eb93f190c5b4253ede0b88f44bf72e8f7ee0206e5eb91'
SIGNATURE = bytes.fromhex('1f 01 00 71 04 19 45 7a 61 00 00 54 00 00 80 52 2a 00 00 14')

if len(sys.argv) != 2:
    sys.exit('Usage: python3 verify_binary.py path/to/HDSViewService')

data = Path(sys.argv[1]).read_bytes()
digest = hashlib.sha256(data).hexdigest()
assert data[:4] == bytes.fromhex('cf fa ed fe'), 'File is not an ARM64 Mach-O executable'
assert digest == SHA256, f'Unexpected binary SHA-256: {digest}'
assert data[0x82310:0x82324] == SIGNATURE, 'Expected branch sequence is missing'
print('MATCH: exact HDSViewService binary and patch point verified; original file unchanged.')
