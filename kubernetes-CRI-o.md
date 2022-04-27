Update & Upgrade both master and worker node, run the following commands on both the nodes -

sudo apt update
sudo apt upgrade

Now add IP address and hostname of master and worker nodes in hosts file. Hosts file resides at path /etc/hosts. Confirm the connectivity via hostname using ping command.

#On master node
ping k8s-crio-worker

#On worker node
ping k8s-crio-master

Next, make sure br_netfilter module is loaded. This module facilitates VxLAN traffic and allows communication between Kubernetes pods across the cluster.
Load it on both the nodes, run the following command - 

sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

We need to make sure our node's iptable are able to view bridged traffic. For this we must enable net.bridge.bridge-nf-call-iptables in your sysctl config on both nodes.

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo sysctl --system

Now let's install our CRI-O container runtime, we'll see what all steps needs to be followed on both nodes to use CRI-O as CRI runtime. Run the following steps on both your master and worker nodes.
Switch to root user and run the following commands on both nodes

export VERSION=1.23
export OS=xUbuntu_20.04
apt install -y libseccomp2

echo "deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" | sudo tee -a /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
echo "deb [signed-by=/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" | sudo tee -a /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list

echo "deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list

echo "deb [signed-by=/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list

mkdir -p /usr/share/keyrings
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-archive-keyring.gpg
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg

apt-get update
apt-get install -y cri-o cri-o-runc cri-tools

systemctl enable crio --now


Exit from root user, and get back to installation of production-environment tools of Kubernetes, we'll bootstrap the clusters with kubeadm, follow the steps on both nodes

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