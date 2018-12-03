#!/usr/bin/env bash

# This is an adapted version of the script found at https://gist.github.com/alexellis/fdbc90de7691a1b9edb545c17da2d975#file-prep-sh

set -euxo pipefail
IFS=$'\n\t'

curl -sSL get.docker.com | sh && \
  sudo usermod pi -aG docker

newgrp docker
apt purge -y docker-ce && apt-autoremove -y
apt install docker-ce=18.06.0~ce~3-0~raspbian

sudo dphys-swapfile swapoff && \
  sudo dphys-swapfile uninstall && \
  sudo update-rc.d dphys-swapfile remove

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - && \
  echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list && \
  sudo apt-get update -q && \
  sudo apt-get install -qy kubeadm

# disables swap at boot
sudo cp /boot/cmdline.txt /boot/cmdline_backup.txt
orig="$(head -n1 /boot/cmdline.txt) cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory"
echo $orig | sudo tee /boot/cmdline.txt

# required by flanell networking:
sudo sysctl net.bridge.bridge-nf-call-iptables=1

sudo reboot
