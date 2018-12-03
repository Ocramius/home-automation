# Home automation

This is a personal setup of a Raspberry PI Kubernetes cluster that I'll use
for the purpose of reducing the security of my LAN.

This is a personal project, and the repository is public and only exists for the
purpose of documenting what is going on: use at your own risk.

# Step 1: get some Raspberry Pi machines

The first step is to set up a bunch of Raspberry Pi 3B+ machines.
These are cheap, run on PoE electricity, and consume between 2.7W
and 5W of power.

The hardware I use:

 * [UniFi PoE Switch 16 - US-16-150W](https://www.ubnt.com/unifi-switching/unifi-switch-16-150w/)
 * [Raspberry PoE Hat](https://www.welectron.com/Raspberry-Pi-PoE-HAT_3)
 * [Raspberry PI 3B+](https://www.welectron.com/Raspberry-Pi-3-Model-B-Made-in-UK)
 * [Raspberry PI Case](https://www.welectron.com/Raspberry-Pi-Official-Case-Gray-Black)
 * [64Gb MicroSDXC](https://www.welectron.com/SanDisk-Ultra-64-GB-A1-UHS-I-Class-10-microSD_1)

In my case, I aim to have at least 3 of these things running.

Set them up, wire them together.

# Step 2: bootstrap the Raspberry Pi machines with Debian Stretch

This step is inspired by [this gist](https://gist.github.com/alexellis/a7b6c8499d9e598a285669596e9cdfa2)

In order to do that, insert the SD card in your computer (I recommend using
an USB SD card adapter, since laptop SD card readers are buggy as hell), then run (as root):

```sh
RPI_SD_CARD_DEVICE=<see-disk-name-through-lsblk-first> \
RPI_HOSTNAME=host-name-of-the-raspberry-pi \
RPI_IP_PART_4=100 \
RPI_AUTHORISED_SSH_KEYS=<your-ssh-public-keys> \
./bin/provision-raspberry-pi-sd-card.sh
```

For example:

```sh
RPI_SD_CARD_DEVICE=sdc \
RPI_HOSTNAME=my-rpi-1 \
RPI_IP_PART_4=253 \
RPI_AUTHORISED_SSH_KEYS=$(ssh-add -L) \
./bin/provision-raspberry-pi-sd-card.sh
```

This may fail if your SDXC was previously formatted, or has bad sectors. If that is
the case, try formatting it manually, and make sure the advertised disk size matches
the one you see in `df -h`.
