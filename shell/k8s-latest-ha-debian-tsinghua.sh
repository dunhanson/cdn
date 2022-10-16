#!/bin/bash
#  

stty erase ^h
echo ""
echo "Kubernetes-高可用集群-安装脚本-Debian"
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
echo "1.2 基础配置-集群节点ip地址设置"
read -p "输入本机节点ip地址:" ip
echo "本机节点ip地址为:$ip"
echo ""

echo "2.Docker配置"
echo "2.1 Docker配置-安装docker预先准备、配置docker源"
sudo apt-get remove docker docker-engine docker.io
sudo apt-get -y install apt-transport-https ca-certificates curl gnupg2 software-properties-common
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian $(lsb_release -cs) stable"
echo ""
echo "2.2 Docker配置-安装docker"
sudo apt-get -y update
sudo apt-get -y install docker-ce
echo ""
echo "2.3 Docker配置-docker服务开启并设置开机启动"
systemctl start docker
systemctl enable docker
echo ""
echo "2.4 Docker配置-关闭swap"
swapoff -a
sed -i 's/^.*swap.*$/#&/' /etc/fstab
echo ""
echo "2.5 Docker配置-cgroupdriver修改（不设置kubeadm init会有警告）"
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

echo "3.Kubernetes配置"
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

echo '3.2 Kubernetes配置-安装 kubeadm、kubelet 和 kubectl'
apt-get update && apt-get install -y apt-transport-https
curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
cat << EOF > /etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.tuna.tsinghua.edu.cn/kubernetes/apt kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl
echo ""

echo '3.3 Kubernetes配置-下载、重命名kubernetes镜像'
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
read -p '是否是main节点?(y/n) ' isMain
if [ $isMain = "y" ]
then
  read -p "输入本机节点网卡名称:" interface
  echo "本机节点网卡名称为:$interface"
  echo ""
  read -p "输入k8s-main-1 ip地址:" k8s_main_1_ip
  echo "k8s-main-1 ip地址为:$k8s_main_1_ip"  
  echo ""
  read -p "输入k8s-main-2 ip地址:" k8s_main_2_ip
  echo "k8s-main-2 ip地址为:$k8s_main_2_ip"  
  echo ""
  read -p "输入k8s-main-3 ip地址:" k8s_main_3_ip
  echo "k8s-main-3 ip地址为:$k8s_main_3_ip"  
  echo ""
  read -p "输入vip地址:" vip
  echo "vip地址为:$vip"  
  echo ""

  other_two_ip=""
  if [ $ip = $k8s_main_1_ip ]
  then
   other_two_ip_1=$k8s_main_2_ip
   other_two_ip_2=$k8s_main_3_ip
  fi
  if [ $ip = $k8s_main_2_ip ]
  then
   other_two_ip_1=$k8s_main_1_ip
   other_two_ip_2=$k8s_main_3_ip
  fi
  if [ $ip = $k8s_main_3_ip ]
  then
   other_two_ip_1=$k8s_main_1_ip
   other_two_ip_2=$k8s_main_2_ip
  fi

  echo "安装Keepalived和HAproxy"
  apt-get install keepalived haproxy -y
  echo ""
  echo "正在配置Haproxy"
  tee /etc/haproxy/haproxy.cfg <<-EOF
global
  log /dev/log  local0 warning
  chroot      /var/lib/haproxy
  pidfile     /var/run/haproxy.pid
  maxconn     4000
  user        haproxy
  group       haproxy
  daemon

  stats socket /var/lib/haproxy/stats

defaults
  log global
  option  httplog
  option  dontlognull
    timeout connect 5000
    timeout client 50000
    timeout server 50000

frontend kube-apiserver
  bind *:7443
  mode tcp
  option tcplog
  default_backend kube-apiserver

backend kube-apiserver
  mode tcp
  option tcplog
  option tcp-check
  balance roundrobin
  default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
  server kube-apiserver-1 $k8s_main_1_ip:6443 check
  server kube-apiserver-2 $k8s_main_2_ip:6443 check
  server kube-apiserver-3 $k8s_main_3_ip:6443 check  
EOF
  systemctl enable haproxy
  systemctl restart haproxy
  echo ""

  echo "正在配置Keepalived"
  tee /etc/keepalived/keepalived.conf <<-EOF
bal_defs {
  notification_email {
  }
  router_id LVS_DEVEL
  vrrp_skip_check_adv_addr
  vrrp_garp_interval 0
  vrrp_gna_interval 0
}

vrrp_script chk_haproxy {
  script "killall -0 haproxy"
  interval 2
  weight 2
}

vrrp_instance haproxy-vip {
  state BACKUP
  priority 100
  interface $interface    # Network card
  virtual_router_id 60
  advert_int 1
  authentication {
    auth_type PASS
    auth_pass 1111
  }
  unicast_src_ip $ip      # The IP address of this machine
  unicast_peer {
    $other_two_ip_1       # The IP address of peer machines
    $other_two_ip_2
  }

  virtual_ipaddress {
    $vip/24               # The VIP address
  }

  track_script {
    chk_haproxy
  }
}
EOF
  systemctl enable keepalived
  systemctl restart keepalived
  echo ""

  # main节点
  read -p "是否是第一个main节点?(y/n):" isFirstMain
  if [ $isFirstMain = "y" ]  
  then
    read -p "k8s-main-2 k8s-main-3节点安装好Haproxy和Keepalived?(任意键继续):" isOtherMainInstallHaproxyAndKeepalived
    echo ""
    echo "初始化main节点"
    kubeadm init \
    --control-plane-endpoint=$vip:7443 \
    --apiserver-advertise-address=$k8s_main_1_ip \
    --pod-network-cidr=10.244.0.0/16 \
    --upload-certs > /tmp/k8s_init_out.txt
    rm -rf $HOME/.kube/config
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    echo "生成join脚本"
    cat /tmp/k8s_init_out.txt | grep -A 3 "kubeadm join" | sed -n '1,3p' > /tmp/k8s_ha_main_join.sh
    cat /tmp/k8s_init_out.txt | grep -A 3 "kubeadm join" | sed -n '1,2p' > /tmp/k8s_ha_node_join.sh    
    echo "安装flannel"
    kubectl create -f https://raw.staticdn.net/coreos/flannel/master/Documentation/kube-flannel.yml
  else
    read -p "k8s-main-1节点安装好Haproxy和Keepalived?(任意键继续):" isOtherMainInstallHaproxyAndKeepalived
    echo ""
    read -p "请输入k8s-main-1节点user:" user
    echo "k8s-main-1节点user为:$user"
    read -p "请输入k8s-main-1节点password:" password
    echo "k8s-main-1节点password为:$password"
    echo ""
    echo "正在初始化main节点"
    apt-get install sshpass -y
    sshpass -p $password scp -o StrictHostKeyChecking=no $user@$k8s_main_1_ip:/tmp/k8s_ha_main_join.sh ~
    join=$(cat ~/k8s_ha_main_join.sh)
    echo "$join \--apiserver-advertise-address=$ip" > ~/k8s_ha_main_join.sh
    sh ~/k8s_ha_main_join.sh
    rm -rf $HOME/.kube/config
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config    
fi
else
  # node节点
  read -p "输入k8s-main-1 ip地址:" k8s_main_1_ip
  echo "k8s-main-1 ip地址为:$k8s_main_1_ip"  
  read -p "请输入k8s-main-1 user:" user
  echo "k8s-main-1 user为:$user"
  read -p "请输入k8s-main-1 password:" password
  echo "k8s-main-1 password为:$password"
  echo ""
  echo "初始化node节点"  
  apt-get install sshpass -y
  sshpass -p $password scp -o StrictHostKeyChecking=no $user@$k8s_main_1_ip:/tmp/k8s_ha_node_join.sh ~
  sh ~/k8s_ha_node_join.sh  
fi
