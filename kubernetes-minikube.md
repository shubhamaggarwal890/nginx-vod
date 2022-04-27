Update and upgrade the minikube node, run the following commands on the node -

sudo apt update
sudo apt upgrade

The best thing about Minikube is you don't have much of the hassle, all we have to do is download the binary of minikube and install locally. For the follow the following commands - 

curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

And that's it, you have successfully installed the kubernetes over the node.

To start the kubernetes cluster, run the following command -

minikube start

And that's it, it sums up the minikube and its installation.