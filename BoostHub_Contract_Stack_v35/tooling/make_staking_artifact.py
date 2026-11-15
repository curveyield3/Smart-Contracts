#!/usr/bin/env python3
"""Compile the single canonical Vyper source into an artifact bound to its exact bytes.
Build helper only: not a deployment script and not a test runner.
"""
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'contracts' / 'BoostHubStaking.vy'
OUT = ROOT / 'artifacts' / 'staking.json'
PIN = '0.4.3'


def vyper(*args):
    return subprocess.check_output(['vyper', *args], text=True).strip()


version = vyper('--version')
if not re.search(r'(?<![0-9])0\.4\.3(?![0-9])', version):
    raise SystemExit(f'Expected Vyper {PIN}; got {version}')


def compile_output(output):
    return vyper('-f', output, str(SOURCE))


artifact = {
    'compilerVersion': PIN,
    'sourceSha256': '0x' + hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'abi': json.loads(compile_output('abi')),
    'bytecode': compile_output('bytecode'),
    'deployedBytecode': compile_output('bytecode_runtime'),
}
if not artifact['bytecode'].startswith('0x') or not artifact['deployedBytecode'].startswith('0x'):
    raise SystemExit('Vyper compiler did not produce hex bytecode')
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(artifact, indent=2) + '\n')
print(f'Vyper {PIN} artifact for {SOURCE.relative_to(ROOT)} -> {OUT.relative_to(ROOT)}')
