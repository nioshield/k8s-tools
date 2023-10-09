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
  echo "############# start create cluster:[${clusterName}] #############"
  workDir=${ROOT}/kind/${clusterName}
  if [ -d ${workDir} ]; then
   echo "cluster ${clustername} is exists, don't repeat create ${workDir}"
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
      cat <<EOF >>  ${configFile}
  - role: worker
    extraMounts:
    - hostPath: ${workDir} 
      containerPath: /data/helm
EOF
  done
  
  kind create cluster --config ${configFile} --image kindest/node:${k8sVersion} --name=${clusterName}
  kind get kubeconfig --name=${clusterName} > ${kubeconfigPath}
  echo "create k8s cluster success"

}

destory() {
    echo "############# start destory cluster:[${clusterName}] #############"
    workDir=${ROOT}/kind/${clusterName}
    kind delete cluster -n ${clusterName}
    if [[ -d ${workDir} ]]; then
        rm -rf ${workDir}
    fi
    echo "destory k8s cluster success"
}

load(){
    echo "############# start load image cluster:[${clusterName}] #############"
    names=(${imageNames//,/ })
    for name in ${names[@]}
    do
        imagePath="${imageRegister}/${name}:${imageVersion}"
        kind load docker-image -n ${clusterName} ${imagePath} & > /dev/null && echo "load image:[${imagePath}]" &
    done
    wait
    echo "load image success"
}



if [[ $# -lt 2 ]];then
    echo "params num err"
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
    -h|--help)
    usage
    exit 0
    ;;
    *)
    echo "unknown option: $key"
    usage
    exit 1
    ;;
esac
done
clusterName=${clusterName:-kind-cls}
nodeNum=${nodeNum:-1}
k8sVersion=${k8sVersion:-v1.23.4}
imageVersion=${imageVersion:-v2.6.2}
imageNames=${imageNames:-chaos-mesh,chaos-daemon}
imageRegister=${imageRegister:-ghcr.io/chaos-mesh}

echo "ROOT: ${ROOT}"
echo "clusterName: ${clusterName}"
echo "nodeNum: ${nodeNum}"
echo "k8sVersion: ${k8sVersion}"
echo "imageVersion: ${imageVersion}"
echo "imageNames: ${imageNames}"
echo "imageRegister=${imageRegister}"

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
    *)
    echo "unknown action: $action"
    usage
    exit 1
esac
