# 使用手册

## 场景
当前验证过的场景是chaos-mesh remote cluster 安装

## init cluster
初始化cluster 通过kind 完成
`kind create cluster --name {cluster name } --config ./remote-cls.yaml`

## cluster 互相访问
* 默认kind 创建的node ip 是自增的，网络内部可以互通
* kubeconfig 文件获取获取的是`127.0.0.1` 地址上的，同时docker映射的宿主机的端口
* 修改kubeconfig 的ip 为kind node  的ip,端口修改为6443
* `docker cp ./remote-internal-k8s.yaml dev-cls-control-plane:/remote-k8s.yaml`

## 镜像导入
* kind load docker-image -n {cluster name} {images}


## kubeconfig.yaml 存储到secret
`kubectl --kubeconfig ./dev-k8s.yaml create secret generic remote-cls --from-file=remote-cls=./remote-internal-k8s.yaml`

## debug pod
修改deploy 启动命令,可以直接通过command/args 两个参数替换,注意请求容器中是否有/bin/bash
```go
containers:
  - name: ubuntu
    image: ubuntu:latest
    # Just spin & wait forever
    command: [ "/bin/sh", "-c", "--" ]
    args: [ "while true; do sleep 30; done;" ]
```
