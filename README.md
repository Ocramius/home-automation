## Archived

Note: this repository is archived, since I moved on from this approach, and will rebuild things from
scratch in future.

My learning is: don't use k8s nor k3s for home automation, rely on `docker-compose` instead,
which is simpler **AND** more reliable, for this sort of work

# Home automation

This is a personal setup of a Raspberry PI Kubernetes cluster that I'll use
for the purpose of reducing the security of my LAN.

This is a personal project, and the repository is public and only exists for the
purpose of documenting what is going on: use at your own risk.

## Step 1: get some Raspberry Pi machines

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

## Step 2: bootstrap the Raspberry Pi machines with Debian Stretch

This step is inspired by [this gist](https://gist.github.com/alexellis/a7b6c8499d9e598a285669596e9cdfa2).

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

## Step 3: configure a Kubernetes cluster

Why? For the glory of Satan, of course.

Jokes apart, I want to know what is running, where it is running, who is accessing it,
and I want to ease upgrading any part of my infrastructure easily. Having a bunch of
Raspberry with manually-installed abandonware on them is NOT ok. I need to be able
to isolate these home automation tools, which are written with terrible tech (TM), such
as NodeJS:

 1. they should run reliably
 2. they DO NOT have access to bare metal
 3. I must be able to turn them off selectively
 4. they should be easily upgraded (if a tool doesn't come with a docker image, I'll make one)
 5. they should have as few moving parts as possible (immutable filesystem, isolated secrets)
 6. resource limited. If something eats too much CPU/RAM, it should be reported to me.
 7. run in a local setup: all of this garbage is NOT to be exposed to the WAN, even by accident.

Plus I will surely stumble on a Raspberry, leading to it crashing. A "Plug and Play" setup
allows me to move them around my network without too much worries about catastrophic failures,
and having to manually re-configure them from scratch, as long as one of them is still running
as `master` node.

The following steps are inspired by https://gist.github.com/alexellis/fdbc90de7691a1b9edb545c17da2d975,
and further refined by me in https://gist.github.com/alexellis/fdbc90de7691a1b9edb545c17da2d975#gistcomment-2775966.

### Disable SWAP, Install Docker, Kubernetes administrative tools

Copy the file at `bin/disable-swap-install-docker-and-kubeadm.sh` into each raspberry that will be part of the cluster,
then run it. Note that this will reboot your raspberry:

```sh
scp bin/disable-swap-install-docker-and-kubeadm.sh pi@192.168.1.100:~/
ssh pi@192.168.1.100
./disable-swap-install-docker-and-kubeadm.sh
```

### Set up master node

Then run this on the node you want to mark as `master` (note: tested with kubernetes `v1.12.3` and docker `18.06.0`):

```sh
sudo kubeadm init --token-ttl=0 --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=192.168.1.100
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

### Join further nodes

To join a node, generate a "join token":

```sh
ssh pi@192.168.1.100 "sudo kubeadm token create --print-join-command"
```

Then run it on the nodes that should join:

```sh
ssh pi@192.168.1.110 "sudo kubeadm join --token <snip> 192.168.1.100:6443 --discovery-token-ca-cert-hash sha256:<snip>"
```

I'd also advise adding the `kubectl` configuration to your own machine. Do this *ONLY* if you
don't already have another configured cluster, as it will overwrite your local configuration:

```sh
mkdir ~/.kube
scp pi@192.168.1.100:~/.kube/config ~/.kube/config
```

You should be able to monitor the cluster from your local machine:

```sh
kubectl get nodes
kubectl get pods
```

## Step 4: configure a reverse proxy and run an application behind it

In order to set up Traefik to serve as an ingress to our application,
I prepared some annotated kubernetes manifests:

```sh
# set up traefik to serve our traffic
kubectl apply -f kubernetes-manifests/traefik-ingress-controller.yml

# start a node-red application (graphical home automation tool)
kubectl apply -f kubernetes-manifests/node-red.yml

# configure the ingress to forward traffic to the various services (including node-red)
kubectl apply -f kubernetes-manifests/ingress.yml
```

When this is done, we should see the running traefik and node-red instances,
with one traefik instance running on each node:

```sh
kubectl get pods --all-namespaces
NAMESPACE     NAME                                        READY   STATUS             RESTARTS   AGE    IP              NODE                NOMINATED NODE
<snip>
default       node-red-7669fd7fbc-52vgn                   1/1     Running            0          18h    10.244.1.23     ocramius-k8s-pi-2   <none>
kube-system   traefik-ingress-controller-9rnc9            1/1     Running            0          115m   10.244.0.4      ocramius-k8s-pi-1   <none>
kube-system   traefik-ingress-controller-25pp8            1/1     Running            0          169m   10.244.1.24     ocramius-k8s-pi-2   <none>
kube-system   traefik-ingress-controller-9rnc9            1/1     Running            0          115m   10.244.2.20     ocramius-k8s-pi-3   <none>
```

You can test the setup by `curl`-ing all hosts:

```sh
curl http://192.168.1.110 # should produce a 404 (expected)
curl http://192.168.1.111 # should produce a 404 (expected)
curl http://192.168.1.112 # should produce a 404 (expected)
curl --header 'Host: traefik-ui.minikube' http://192.168.1.110 # should redirect to /dashboard/
curl --header 'Host: traefik-ui.minikube' http://192.168.1.111 # should redirect to /dashboard/
curl --header 'Host: traefik-ui.minikube' http://192.168.1.112 # should redirect to /dashboard/
curl --header 'Host: node-red.minikube' http://192.168.1.110 # should be some node-red HTML
curl --header 'Host: node-red.minikube' http://192.168.1.111 # should be some node-red HTML
curl --header 'Host: node-red.minikube' http://192.168.1.112 # should be some node-red HTML
```

## Step 5: configuring storage

In a distributed environment, persistent storage is a bit tricky, since you
can't rely on the storage of a single node within the cluster to save/load
information, as any node may be removed/moved and/or fail.

In order for storage to be persistent, we'll configure an NFS server. Any of
your raspberry pi will do. In my case, I (ab-)used my k8s master node, which
isn't really ding much, and used an external SSD as storage (the internal SD
card is unreliable: avoid it).

Since we're running Raspian, the setup for the NFS server is like on Debian:

```sh
ssh pi@192.168.1.100
sudo su

# configured the external SSD (which I previously formatted as ext4) to mount at startup
mkdir -p /mnt/k8s-volumes
echo "/dev/sda1 /mnt/k8s-volumes ext4 defaults 0 2" >> /etc/fstab
mount -a

apt-get install -y nfs-kernel-server
# share the SSD, restrict access to 192.168.1.97~192.168.1.126 - good enough for my LAN
echo "/mnt/k8s-volumes 192.168.1.96/27(rw,sync,no_root_squash,no_subtree_check)" >> /etc/exports

# reload exports
exportfs -ra

# show what's being shared
showmount -e 127.0.0.1
```

You should be able to access the volume from any of the other cluster nodes:

```sh
ssh pi@192.168.1.110
sudo su
mkdir foo
mount 192.168.1.100:/mnt/k8s-volumes ./foo

# ... play around with the volume ...

# lazy-unmount (NFS is a bit annoying/blocking otherwise)
umount -l ./foo
```

Now we can instruct our k8s cluster to use NFS as a PersistentVolume (PV),
and a PersistentVolumeClaim (PVC) that "grabs" it. Note that in a cloud
environment, you would have multiple PVCs, because sysadmins provide the
hardware resources (PV), and developers consume them (PVC). In our setup,
that would be too much work, because we'd have to configure a new PV for
each PVC manually (they live in a one-to-one "best-fit-wins" relationship).
Instead, we will use a single PV (the NFS mount) with a single PVC, and
then configure a `subPath` property when mounting volumes in a container.
If we don't use the `subPath` volume mount option, the root of the PV will
be used, and that's a nice recipe for disaster.

```sh
kubectl apply -f kubernetes-manifests/nfs-persistent-volume.yml
kubectl apply -f kubernetes-manifests/nfs-persistent-volume-claim.yml
```

#### Optional: checking the persistent volume

You can now mount the persistent volume claim in any deployment
configuration.

For example, here's a busybox container (which does nothing, but useful
to play around with `kubectl exec -ti <name-of-container> -- sh` once it
is running):

```yml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: example-empty-app
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: example-empty-app
    spec:
      containers:
        - name: busybox-example
          image: busybox
          command: ['sleep', '3600']
          imagePullPolicy: Always
          volumeMounts:
            # name must match the volume name below
            - name: a-volume-name
              mountPath: "/example"
              subPath: "a-unique-subpath"
      volumes:
      - name: a-volume-name
        persistentVolumeClaim:
          claimName: nfs-persistent-volume-claim
```

#### Use a `subPath`!

Note: it is **VITAL** that you specify a `subPath`
in `spec/template/spec/containers/*/volumeMounts`! Without that entry, you
will be writing to the root of the NFS mount, and that can seriously cause
a mess! This is in no way what should happen in a production environment:
please use separate PVs and PVCs for that, even if it is more tedious to
configure.
