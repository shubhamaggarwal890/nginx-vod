Update & Upgrade both master and worker node, run the following commands on both the nodes -

sudo apt update
sudo apt upgrade

Now add IP address and hostname of master and worker nodes in hosts file. Hosts file resides at path /etc/hosts. Confirm the connectivity via hostname using ping command.

#On master node
ping k8s-containerd-worker

#On worker node
ping k8s-containerd-master

Next, make sure br_netfilter module is loaded. This module facilitates VxLAN traffic and allows communication between Kubernetes pods across the cluster.
Load it on both the nodes, run the following command - 

sudo modprobe br_netfilter

We need to make sure our node's iptable are able to view bridged traffic. For this we must enable net.bridge.bridge-nf-call-iptables in your sysctl config on both nodes.

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo sysctl --system

Now let's install our containerd container runtime, we'll see what all steps needs to be followed on both nodes to use containerd as CRI runtime. Run the following steps on both your master and worker nodes.

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

Let's install containerd from official binaries, download the binary using following command and then extract it under /usr/local on both nodes.

wget https://github.com/containerd/containerd/releases/download/v1.6.2/containerd-1.6.2-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local containerd-1.6.2-linux-amd64.tar.gz

Now start containerd via systemd. Let's download the containerd.service file into /usr/local/lib/systemd/system/containerd.service. Follow the commands on both nodes-

wget https://github.com/containerd/containerd/raw/main/containerd.service
sudo mkdir -p /usr/local/lib/systemd/system/
sudo mv containerd.service /usr/local/lib/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

We'll install runc on both nodes.

wget https://github.com/opencontainers/runc/releases/download/v1.1.1/runc.amd64
sudo install -m 755 runc.amd64 /usr/local/sbin/runc

Finally in the step of installation of containerd, let's now install CNI plugins and extract it under /opt/cni/bin on both nodes

wget https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.1.1.tgz

We have to generate default configuration file for containerd, this configuration file is in /etc/containerd/config.toml and it can be populated using following command, do it on both nodes

sudo mkdir /etc/containerd
containerd config default | sudo tee -a /etc/containerd/config.toml

We have successfully installed containerd, runc and CNI, finally configure systemd cgroup driver in /etc/containerd/config.toml with runc, set it on both nodes

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  ...
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true

Run the following command on both nodes, to restart the containerd daemon process. 

sudo systemctl restart containerd

Now let's get back to installation of production-environment tools of Kubernetes, we'll bootstrap the clusters with kubeadm, follow the steps on both nodes

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

Turn off swap space on both nodes.

sudo swapoff -a

Let's initialize the single control plane on master on our Kubernetes cluster, run the following command on master node.

sudo kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
#To deploy POD network, here we are using kube-flannel (Kubernetes networking model)
kubectl apply -f https://github.com/coreos/flannel/raw/master/Documentation/kube-flannel.yml

After the successful completion, you will be prompted to join worker nodes, run the following command on worker node as root

sudo kubeadm join <control-plane-host>:<control-plane-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>

On master node, view all the pods running using following command

kubectl get pods --all-namespaces -o wide

On master node, view the node details using following command

kubectl get nodes -o wide