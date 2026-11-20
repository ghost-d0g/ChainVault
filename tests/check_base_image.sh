#!/usr/bin/env bash
set -uo pipefail

IMG=${1:-packer/output-debian-base/debian13-base.qcow2}
PORT=2222
USER=packer
PASS=packer
ACCEL=${ACCEL:-kvm}

[ -f "$IMG" ] || { echo "image not found: $IMG"; exit 2; }
command -v sshpass >/dev/null || { echo "install sshpass first"; exit 2; }

PIDFILE=$(mktemp)
trap 'kill "$(cat "$PIDFILE")" 2>/dev/null; rm -f "$PIDFILE"' EXIT

qemu-system-x86_64 -accel "$ACCEL" -m 1024 -smp 2 -display none \
-drive "file=$IMG,if=virtio,format=qcow2" -snapshot \
-netdev "user,id=n0,restrict=on,hostfwd=tcp:127.0.0.1:$PORT-:22" \
-device virtio-net-pci,netdev=n0 \
-daemonize -pidfile "$PIDFILE" || { echo "qemu failed to start"; exit 2; }

vm()
{
    sshpass -p "$PASS" ssh -p "$PORT" -o StrictHostKeyChecking=no\
    -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5 \
    "$USER@127.0.0.1" "$@"
}

fails=0
check() {
    local desc=$1; shift
    if "$@" >/dev/null 2>&1; then echo "ok $desc"; else echo "FAIL $desc"; fails=$((fails + 1));fi
}

for _ in $(seq 60); do vm true 2>/dev/null && break; sleep 3; done 
check "ssh login works" vm true
check "is Debian 13"    vm 'grep -q "^VERSION_ID=\"13\"" /etc/os-release'
check "sudo works without tty"  vm 'sudo -n true'
check "sshd is active"  vm 'sudo systemctl is-active --quiet ssh'
check "no outboud network" vm '! timeout 3 bash -c "</dev/tcp/8.8.8.8/53"'

echo "$fails check(s) failed"
exit $((fails > 0))