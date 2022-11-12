# 准备工作（例子）
# 1、设置hostname
# timedatectl set-timezone Asia/Shanghai
# hostnamectl set-hostname xx
# 2、设置hosts
# echo "192.168.33.10 debian11" >> /etc/hosts
# 3、设置环境变量ip
# echo "export NODE_IP='192.168.33.10'" >> /etc/profile
# echo "export MAIN_FLAG='true'" >> /etc/profile
# source /etc/profile

NODE_IP='192.168.33.80'
MAIN_FLAG='true'

if [ "$MAIN_FLAG" = "" ]
then
  echo "初始化环境变量MAIN_FLAG未设置"
  exit 1
fi

if [ "$NODE_IP" = "" ]
then
  echo "初始化环境变量NODE_IP未设置"
  exit 1
fi

# 1、基本配置
# 源
tee /etc/apt/sources.list <<-'EOF'
deb https://mirrors.ustc.edu.cn/debian/ bullseye main non-free contrib
deb-src https://mirrors.ustc.edu.cn/debian/ bullseye main non-free contrib
deb https://mirrors.ustc.edu.cn/debian-security/ bullseye-security main
deb-src https://mirrors.ustc.edu.cn/debian-security/ bullseye-security main
deb https://mirrors.ustc.edu.cn/debian/ bullseye-updates main non-free contrib
deb-src https://mirrors.ustc.edu.cn/debian/ bullseye-updates main non-free contrib
deb https://mirrors.ustc.edu.cn/debian/ bullseye-backports main non-free contrib
deb-src https://mirrors.ustc.edu.cn/debian/ bullseye-backports main non-free contrib
EOF
apt-get update -y

# 2、安装docker
sudo apt-get remove docker docker-engine docker.io
sudo apt-get -y install apt-transport-https ca-certificates curl gnupg2 software-properties-common
curl -fsSL https:///mirrors.ustc.edu.cn/docker-ce/linux/debian/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://mirrors.ustc.edu.cn/docker-ce/linux/debian $(lsb_release -cs) stable"
sudo apt-get -y update
# 安装指定版本
# apt-cache madison docker-ce | awk '{ print $3 }'
sudo apt-get -y install docker-ce=5:20.10.21~3-0~debian-bullseye
# 启动docker
systemctl start docker
systemctl enable docker
# 关闭swap
swapoff -a
sed -i 's/^.*swap.*$/#&/' /etc/fstab
# 配置加速和设置systemd
mkdir -p /etc/docker
tee /etc/docker/daemon.json <<-'EOF'
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors": ["https://hub-mirror.c.163.com"]
}
EOF
systemctl daemon-reload
systemctl restart docker

# 3、kubernetes
# 允许 iptables 检查桥接流量
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
# 安装 kubeadm、kubelet 和 kubectl
apt-get update && apt-get install -y apt-transport-https
curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - 
cat << EOF > /etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.ustc.edu.cn/kubernetes/apt/ kubernetes-xenial main
EOF
# 安装指定版本
apt-get update
# apt-cache madison kubeadm
apt-get install -y kubelet=1.21.14-00 kubeadm=1.21.14-00 kubectl=1.21.14-00
# 设置kubernetes节点ip
sed -i '/KUBELET_CONFIG_ARGS=/a'Environment=\"KUBELET_EXTRA_ARGS=--node-ip=$NODE_IP\" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
systemctl daemon-reload
systemctl restart docker
# main节点初始化
if [ $MAIN_FLAG = 'true' ] 
then
  kubeadm init \
  --apiserver-advertise-address=$NODE_IP \
  --pod-network-cidr=10.244.0.0/16 \
  --image-repository registry.aliyuncs.com/google_containers
  # kubernetes环境变量
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config  
  # 安装flannel
  kubectl create -f https://cdn-github.dunhanson.site/kubernetes/flannel-v0.20.1.yml
fi
echo "finish."