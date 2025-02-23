#!/usr/bin/env sh

echo '# Allow sudo without password for sudo users' >> /etc/sudoers.d/wimsey-defaults
echo '%sudo   ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
