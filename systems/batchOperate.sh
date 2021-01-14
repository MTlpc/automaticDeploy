#! /bin/bash

# hostname=$1

#1.ip地址修改，目前只能每台机器独自修改ip地址
# echo "1.ip地址修改暂无"

#2.修改机器名hostname
# echo "2.修改hostname为node1"
# /home/hadoop/automaticDeploy/systems/changeHostname.sh $hostname

# NTP时间同步
yum install ntpdate -y
ntpdate cn.pool.ntp.org 

# host配置文件修改
echo "将集群ip及其映射的hostname添加到/etc/hosts中"
/home/hadoop/automaticDeploy/systems/addClusterIps.sh

# 关闭防火墙、SELINUX ，需要输入参数close或start
echo "关闭防火墙、SELINUX"
/home/hadoop/automaticDeploy/systems/closeFirewall.sh close

# 添加bigdata用户名 ，需要输入参数create或delete
# echo "添加bigdata用户名"
# /home/hadoop/automaticDeploy/systems/autoCreateUser.sh create

# 配置yum源
# echo "配置yum源"
# /home/hadoop/automaticDeploy/systems/configureYum.sh $hostname

# 配置SSH无密码登录
echo "集群各节点之间配置SSH无密码登录"
/home/hadoop/automaticDeploy/systems/sshFreeLogin.sh

# 配置JDK环境
echo "配置jdk环境"
/home/hadoop/automaticDeploy/systems/configureJDK.sh

#9.配置SCALA环境
# echo "9.配置scala环境"
# /home/hadoop/automaticDeploy/systems/configureScala.sh
echo "--------------------"
echo "|   环境初始化成功！|"
echo "--------------------"