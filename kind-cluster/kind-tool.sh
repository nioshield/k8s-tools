#!/usr/bin/env bash

set -e

ROOT=$(pwd)

usage() {
    cat <<EOF
This script use kind to create Kubernetes cluster,about kind please refer: https://kind.sigs.k8s.io/
Before run this script,please ensure that:
* have installed docker
* have installed helm
Options:
       -h,--help               prints the usage message
       -n,--name               name of the Kubernetes cluster, default value: kind-cls
       -c,--nodeNum            the count of the cluster nodes, default value: 1
       -k,--k8sVersion         version of the Kubernetes cluster, default value: v1.23.4
       -p,--hostPort           host port of the Kubernetes cluster, default value: 32293 
       -iv,--imageVersion      version of the Load docker-images, default value: v2.6.2
       -in,--imageNames        name of the Load docker-images, use "," interval, default value: chaos-mesh,chaos-daemon
       -ir,--imageRegister     register of the Load docker-images, default value: ghcr.io/chaos-mesh
Actions:
      create                  create Kubernetes cluster
      destory                 delete Kubernetes cluster
      load                    load docker images to Kubernetes cluster
Usage:
    $0 carete --name testCluster --nodeNum 4 --k8sVersion v1.20.7
EOF
}

create() {
  log_info "############# start create cluster:[${clusterName}] #############"
  workDir=${ROOT}/kind/${clusterName}
  if [ -d ${workDir} ]; then
   log_error "cluster ${clustername} is exists, don't repeat create ${workDir}"
   exit 1;
  fi
  mkdir -p ${workDir}
  
  configFile=${workDir}/kind-config.yaml
  kubeconfigPath=${workDir}/k8s-config.yaml
  
  cat <<EOF > ${configFile}
  kind: Cluster
  apiVersion: kind.x-k8s.io/v1alpha4
  nodes:
  - role: control-plane
EOF
  
  for ((i=0;i<nodeNum;i++))
  do
      tmpHostPort=$(($hostPort+$i))
      log_info "generator host port:[${tmpHostPort}]"
      cat <<EOF >>  ${configFile}
  - role: worker
    extraPortMappings:
    - containerPort: ${tmpHostPort}
      hostPort: ${tmpHostPort}
      listenAddress: "0.0.0.0"
    extraMounts:
    - hostPath: ${workDir} 
      containerPath: /data/helm
EOF

  done
  
  kind create cluster --config ${configFile} --image kindest/node:${k8sVersion} --name=${clusterName}
  kind get kubeconfig --name=${clusterName} > ${kubeconfigPath}
  log_info "create k8s cluster success"

}

destory() {
    log_info "############# start destory cluster:[${clusterName}] #############"
    workDir=${ROOT}/kind/${clusterName}
    kind delete cluster -n ${clusterName}
    if [[ -d ${workDir} ]]; then
        rm -rf ${workDir}
    fi
    log_info "destory k8s cluster success"
}

load(){
    log_info "############# start load image cluster:[${clusterName}] #############"
    names=(${imageNames//,/ })
    for name in ${names[@]}
    do
        imagePath="${imageRegister}/${name}:${imageVersion}"
        kind load docker-image -n ${clusterName} ${imagePath} & > /dev/null && echo "load image:[${imagePath}]" &
    done
    wait
    log_info "load image success"
}

remote(){
   create
   load
   
   currentClsName=$clusterName
   clusterName="${clusterName}-remote"
   hostPort=$(($hostPort+10))
   info

   create
   load
   apply_remote_k8sconf $currentClsName $clusterName
}

destory_remote(){
    destory

    clusterName="${clusterName}-remote"
    destory
}

apply_remote_k8sconf(){
  if [[ $# -lt 2 ]];then
      log_error "apply remote k8s config params num err"
      exit 1
  fi
  devCls=$1
  remoteCls=$2 
  devDir=${ROOT}/kind/${devCls}
  remoteDir=${ROOT}/kind/${remoteCls}
  remoteIp=`kubectl --kubeconfig ${remoteDir}/k8s-config.yaml get node ${remoteCls}-control-plane -o=jsonpath="{.status.addresses[0].address}"`
  log_info "get remote cls api server ${remoteIp}"
  cp "${remoteDir}/k8s-config.yaml" "${remoteDir}/k8s-inner-config.yaml"
  sed -i '' "s/127.0.0.1:[0-9]*/${remoteIp}:6443/g" "${remoteDir}/k8s-inner-config.yaml"
  kubectl --kubeconfig ${devDir}/k8s-config.yaml create secret generic ${remoteCls} --from-file=${remoteCls}=${remoteDir}/k8s-inner-config.yaml
  log_info "apply ${remoteCls} config to ${devCls} success"
}

info(){
  log_info "ROOT: ${ROOT}"
  log_info "clusterName: ${clusterName}"
  log_info "nodeNum: ${nodeNum}"
  log_info "k8sVersion: ${k8sVersion}"
  log_info "hostPort: ${hostPort}"
  log_info "imageVersion: ${imageVersion}"
  log_info "imageNames: ${imageNames}"
  log_info "imageRegister=${imageRegister}"
}

log_info(){
   echo -e "\033[32m $1 \033[0m "
}

log_error(){
    echo -e "\033[1;31m $1  \033[0m "
}


if [[ $# -lt 2 ]];then
    log_error "params number err"
    usage
    exit 0
fi

action="$1"
shift

while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -n|--name)
    clusterName="$2"
    shift
    shift
    ;;
    -c|--nodeNum)
    nodeNum="$2"
    shift
    shift
    ;;
    -k|--k8sVersion)
    k8sVersion="$2"
    shift
    shift
    ;;
    -iv|--imageVersion)
    imageVersion="$2"
    shift
    shift
    ;;
    -in|--imageNames)
    imageNames="$2"
    shift
    shift
    ;;
    -ir|--imageRegister)
    k8sVersion="$2"
    shift
    shift
    ;;
    -p|--hostPort)
    hostPort="$2"
    shift
    shift
    ;;
   -h|--help)
    usage
    exit 0
    ;;
    *)
    log_error "unknown option: $key"
    usage
    exit 1
    ;;
esac
done
clusterName=${clusterName:-kind-cls}
nodeNum=${nodeNum:-1}
k8sVersion=${k8sVersion:-v1.23.4}
hostPort=${hostPort:-32293}
imageVersion=${imageVersion:-v2.6.2}
imageNames=${imageNames:-chaos-mesh,chaos-daemon}
imageRegister=${imageRegister:-ghcr.io/chaos-mesh}

info

case $action in
    create)
    create
    exit 0
    ;;
    destory)
    destory
    exit 0
    ;;
    load)
    load
    exit 0
    ;;
    remote)
    remote
    exit 0
    ;;
    destory_remote)
    destory_remote
    exit 0
    ;;
    *)
    log_error "unknown action: $action"
    usage
    exit 1
esac
