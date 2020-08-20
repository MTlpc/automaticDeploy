#! /bin/bash

#/home/hadoop/host_ip.txt文件中读取ip和hostname
while read line
do
  #提取文件中的用户名
  hostname=`echo $line | cut -d " " -f2`
  echo " --------节点 $hostname 日志开始生成-------"
  ssh -n $hostname "source /etc/profile && java -classpath /opt/frames/lib/log-collector-1.0-SNAPSHOT-jar-with-dependencies.jar com.atguigu.appclient.AppMain > /var/log/mall_launch.log &"
done < /home/hadoop/automaticDeploy/host_ip.txt #读取存储ip的文件