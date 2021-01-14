#! /bin/bash

function configureNode()
{
 #1.在frames.txt中查看是否需要安装nodejs
 nodeInfo=`egrep "node" /home/hadoop/automaticDeploy/frames.txt`
 
 node=`echo $nodeInfo | cut -d " " -f1`
 isInstall=`echo $nodeInfo | cut -d " " -f2`

 #是否安装
 if [[ $isInstall = "true" ]];then
 
    #2.查看/opt/frames目录下是否有nodejs安装包
    nodeIsExists=`find /opt/frames -name $node`
    
    if [[ ${#nodeIsExists} -ne 0 ]];then
        
        if [ -d /usr/lib/node ];then
              rm -rf /usr/lib/node
        fi
 
        mkdir /usr/lib/node && chmod -R 777 /usr/lib/node
   
        #3.解压到指定文件夹/usr/lib/node中 
        echo "开启解压NodeJS安装包"
        tar -xf $nodeIsExists -C /usr/lib/node >& /dev/null
        echo "NodeJS安装包解压完毕"

        node_home=`find /usr/lib/node/ -maxdepth 1 -name "node-*"`
        
        #4.在/etc/profile配置NODE_HOME
        profile=/etc/profile
        sed -i "/^export NODE_HOME/d" $profile
        echo "export NODE_HOME=$node_home" >> $profile
 
        #5.在/etc/profile配置PATH
        sed -i "/^export PATH=\$PATH:\$NODE_HOME\/bin/d" $profile
        echo "export PATH=\$PATH:\$NODE_HOME/bin" >> $profile

        #6.更新/etc/profile文件
        source /etc/profile && source /etc/profile

        #7.配置国内镜像源
        # npm install -g cnpm --registry=https://registry.npm.taobao.org
        npm config set registry https://registry.npm.taobao.org
        npm config get registry

    else
         echo "/opt/frames目录下没有NodeJS安装包"
    fi
 else
     echo "NodeJS不允许被安装"
 fi
}

configureNode
