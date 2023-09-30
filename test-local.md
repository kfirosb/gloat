To test local

install k3s 
curl -sfL https://get.k3s.io | sh -
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

Then follow the README.md.

you can pass the image to your cluster k3s by run:

docker build -t tsunami .

docker save tsunami:latest | sudo k3s ctr images import -

uninstall k3s

/usr/local/bin/k3s-uninstall.sh

/usr/local/bin/k3s-agent-uninstall.sh
