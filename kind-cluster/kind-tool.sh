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
       -la,--loadAllNodes      load docker-image to all nodes include controller node, default false
       -d,--chartDir           chaos-mesh helm chart dir, default /home/chaos-mesh
       -hv,--helmValues        values string array for helm chart, default images.tag=v2.6.2,controllerManager.replicaCount=1,dashboard.create=false,dnsServer.create=false
       -id,--ignoreDevPatch    ignore dev env cmd and args path for chaos-controller-manager, default false
Actions:
      create                  create Kubernetes cluster
      destory                 delete Kubernetes cluster
      load                    load docker images to Kubernetes cluster
      remote                  create dev cluster and a remoute cluster,load default docker image to cluster work node
      destory_remote          destory dev and remote cluster
      install_chaos           use Helm chart install chaos-mesh, replace conatiner cmd to dev mod, if set --skipDev the ignoer replace cmd action
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
    nodeList=`kubectl get nodes -o go-template --template='{{range.items}}{{printf "%s\n" .metadata.name}}{{end}}' | grep -v "control-plane" | tr '\n' ','`
    nodeList=${nodeList%,*}
    loadCmd="--nodes ${nodeList}" 
    if [ "$loadAllNodes" == "true" ]; then
      loadCmd=""
    fi
    log_info "get work node names[[${nodeList}]]"
    for name in ${names[@]}
    do
        imagePath="${imageRegister}/${name}:${imageVersion}"
        kind load docker-image -n ${clusterName} ${loadCmd} ${imagePath} & > /dev/null && echo "load image:[${imagePath}]" &
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

install_chaos(){
  log_info "############# install chaos-mesh:[${clusterName}] #############"
  k8sConf=${ROOT}/kind/${clusterName}/k8s-config.yaml
  if [ ! -f $k8sConf ]; then
    log_error "k8s config ${k8sConf} is not exists, can not install chaos-mesh"
    exit 1;
  fi
  if [ ! -d $chartDir ]; then
    log_error "Helm chart ${chartDir} is not exits"
    exit 1; 
  fi
  setValue=""
  if [ -z "$helmValues" ];then
      setValue="--set ${helmValue}"
  fi
  log_info `kubectl --kubeconfig ${k8sConf} create ns chaos-mesh`
  helm --kubeconfig ${k8sConf} install chaos-mesh ${chartDir} -n chaos-mesh ${setValue}
  
  if [ "$ignoreDevPatch" == "false" ]; then
    kubectl --kubeconfig ${k8sConf} patch deployment chaos-controller-manager -p '{"spec":{"template":{"spec":{"containers":[{"name":"chaos-mesh","command":["/bin/sh", "-c", "--"],"args":["while true; do sleep 30; done;"]}]}}}}' -n chaos-mesh 
  fi
  log_info "install chaos-mesh end"
}

uninstall_chaos(){
  log_info "############# uninstall chaos-mesh:[${clusterName}] #############"
  k8sConf=${ROOT}/kind/${clusterName}/k8s-config.yaml
  if [ ! -f $k8sConf ]; then
    log_error "k8s config ${k8sConf} is not exists, can not uninstall chaos-mesh"
    exit 1;
  fi
  helm --kubeconfig ${k8sConf} uninstall chaos-mesh -n chaos-mesh 
  log_info "uninstall chaos-mesh end"
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
  log_info "loadAllNodes=${loadAllNodes}"
  log_info "chartDir=${chartDir}"
  log_info "helmValues=${helmValues}"
  log_info "ignoreDevPatch=${ignoreDevPatch}"
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
    -la|--loadAllNodes)
    loadAllNodes="$2"
    shift
    shift
    ;;
    -d|--chartDir)
    chartDir="$2"
    shift
    shift
    ;;
    -hv|--helmValues)
    chartDir="$2"
    shift
    shift
    ;;
    -id|--ignoerDevPatch)
    ignoreDevPatch="$2"
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
loadAllNodes=${loadAllNodes:-false}
chartDir=${chartDir:-/home/chaos-mesh/}
helmValues=${helmValues:-images.tag=v2.6.2,controllerManager.replicaCount=1,dashboard.create=false,dnsServer.create=false}
ignoreDevPatch=${ignoreDevPatch:-false}

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
    install_chaos)
    install_chaos
    exit 0
    ;;
    uninstall_chaos)
    uninstall_chaos
    exit 0
    ;;
    *)
    log_error "unknown action: $action"
    usage
    exit 1
esac
