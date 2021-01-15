#! /bin/bash

function clusterOperate()
{
  
 current_host=`hostname`

 # 移动安装包到/opt/frames下
 echo "移动安装包到/opt/frames下"
 mv /home/hadoop/automaticDeploy/frames /opt/

 # 本地初始化
 /home/hadoop/automaticDeploy/systems/batchOperate.sh

 #1.遍历主机列表
  while read line;
  do
    hostname=`echo $line | cut -d " " -f2`
    echo "目前正在设置$hostname节点的系统环境"
    
    #为其它远程主机复制文件
    if [[ $hostname != $current_host ]]
    then
        #3.远程主机操作
        if ssh -n $hostname test -e /home/hadoop/automaticDeploy
        then
             #3.1 存在则先删除旧的
             ssh -n $hostname "rm -rf /home/hadoop/automaticDeploy"
        fi

        ssh -n $hostname "mkdir -p /home/hadoop/automaticDeploy"
 
        #3.2 把本地的automaticDeploy里面的脚本文件复制到远程主机上
        scp -r /home/hadoop/automaticDeploy/ $hostname:/home/hadoop/automaticDeploy/

        #3.3 把本地的/opt/frames里的软件安装包复制到远程主机的/opt/frames上
        #判断远程主机上/opt/frames是否存在，不存在则创建 
        if ssh -n $hostname test -e /opt/frames/;then
            echo "/opt/frames/已经存在" > /dev/null
        else
            ssh -n $hostname "mkdir /opt/frames"
        fi

        # 安装包分发
        scp -r /opt/frames/* $hostname:/opt/frames/
   
        #遍历需要安装的软件
        # while read lineString;
        # do
        #   software=`echo $lineString | cut -d " " -f1`
        #   isInstall=`echo $lineString | cut -d " " -f2`
        #   if [[ $isInstall = "true" ]];then
        #       if ssh -n $hostname test -e /opt/frames/$software;then
        #           echo "安装包已存在" > /dev/null
        #       else  
        #           scp /opt/frames/$software $hostname:/opt/frames/$software
        #       fi
        #   fi
        # done < /home/hadoop/automaticDeploy/frames.txt
 
        #4.远程执行文件
        ssh -n $hostname /home/hadoop/automaticDeploy/systems/batchOperate.sh
    fi
  done < /home/hadoop/automaticDeploy/host_ip.txt

}

clusterOperate
