#!/bin/bash
#  

stty erase ^h
echo ""
echo "Kubernetes安装脚本-Debian"
echo "作者:dunhanson"
echo ""

echo "1.基础配置"
echo ""
echo "1.1 基础配置-正在配置Debian国内源"
tee /etc/apt/sources.list <<-'EOF'
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-updates main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-backports main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bullseye-security main contrib non-free
EOF
apt-get update -y
echo "" 
read -p "1.2 基础配置-请输入本机节点ip地址:" ip
echo "本机节点ip地址为:$ip"
echo ""
echo "基础配置完成。"
echo ""

echo "2.Docker配置"
echo ""
echo "2.1 Docker配置-预先准备、配置源"
sudo apt-get remove docker docker-engine docker.io
sudo apt-get -y install apt-transport-https ca-certificates curl gnupg2 software-properties-common
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian $(lsb_release -cs) stable"
echo ""
echo "2.2 Docker配置-安装Docker"
sudo apt-get -y update
sudo apt-get -y install docker-ce
echo ""
echo "2.3 Docker配置-Docker服务开启并设置开机启动"
systemctl start docker
systemctl enable docker
echo "2.4 Docker配置-关闭swap"
swapoff -a
sed -i 's/^.*swap.*$/#&/' /etc/fstab
echo ""
echo "2.5Docker配置-cgroupdriver修改（不设置kubeadm init会有警告）"
mkdir -p /etc/docker
tee /etc/docker/daemon.json <<-'EOF'
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors": ["https://docker.mirrors.ustc.edu.cn"]
}
EOF
echo ""
echo "2.6 Docker配置-重启docker"
systemctl daemon-reload
systemctl restart docker
echo ""
echo "Docker配置完成。"
echo ""

echo "3.Kubernetes配置"
echo ""
echo '3.1 Kubernetes配置-允许 iptables 检查桥接流量'
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
echo ""
echo "3.2 Kubernetes配置-安装 kubeadm、kubelet 和 kubectl"
apt-get update && apt-get install -y apt-transport-https
curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
cat << EOF > /etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.tuna.tsinghua.edu.cn/kubernetes/apt kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl
echo ""
echo "3.3 Kubernetes配置-下载、重命名kubernetes镜像"
origin_url=k8s.gcr.io
registry_url=registry.aliyuncs.com/google_containers
kubeadm config images pull --image-repository $registry_url
kubeadm config images list | while read image
do
  echo $image
  hubImage=$(echo $image | cut -d '/' -f 2- | cut -d '/' -f 2-)
  hubImage=$registry_url/$hubImage
  echo $hubImage
  docker pull $hubImage
  docker tag $hubImage $image
  docker rmi $hubImage	
done
echo ""
echo "3.4 Kubernetes配置-正在配置节点IP"
sed -i '/KUBELET_CONFIG_ARGS=/a'Environment=\"KUBELET_EXTRA_ARGS=--node-ip=$ip\" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
systemctl daemon-reload
systemctl restart docker
echo ""
echo "3.5 Kubernetes配置-初始化节点"
read -p "是否是main节点?(y/n) " isMain
if [ $isMain = "y" ]
then
  # 初始化
  kubeadm init \
  --apiserver-advertise-address=$ip \
  --pod-network-cidr=10.244.0.0/16
  # token
  token=$(kubeadm token list | awk '{print$1}' | sed -n '2p')
  hash=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
  join="kubeadm join $ip:6443 --token $token --discovery-token-ca-cert-hash sha256:$hash"
  echo $join > /tmp/join.sh
  # 环境变量
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config  
  # flannel
  kubectl create -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
else
  read -p "请输入main节点ip:" main_ip
  echo "main节点ip为:$main_ip"
  read -p "请输入main节点user:" user
  echo "main节点user为:$user"
  read -p "请输入main节点password:" password
  echo "main节点password为:$password"
  apt-get install sshpass -y
  sshpass -p $password scp -o StrictHostKeyChecking=no $user@$main_ip:/tmp/join.sh ~
  sh ~/join.sh
fi
echo ""
echo "Kubernetes配置完成。"
echo ""


