# automaticDeploy
大数据环境一键安装脚本

# 适用环境
CentOS 7以上

# 使用方法
1. 在/home下创建hadoop目录，用于存放脚本

```
mkdir /home/hadoop
```

2. 下载脚本到/home/hadoop目录下

```
git clone https://github.com/MTlpc/automaticDeploy.git
```

3. 进入到/home/hadoop/automaticDeploy目录下，配置host_ip.txt

```
# 配置集群信息，格式为：ip hostname user password
192.168.31.41 node01 root 123456
192.168.31.42 node02 root 123456
192.168.31.43 node03 root 123456
```

4. 将对应组件的安装包放置到/home/hadoop/automaticDeploy/frames目录中

5. 配置frames.txt，填写安装包全称，以及需要安装的节点

```
# 通用环境
jdk-8u144-linux-x64.tar.gz true
azkaban-sql-script-2.5.0.tar.gz true
# Node01
hadoop-2.7.7.tar.gz true node01
# Node02
mysql-rpm-pack-5.7.28 true node02
azkaban-executor-server-2.5.0.tar.gz true node02
azkaban-web-server-2.5.0.tar.gz true node02
presto-server-0.196.tar.gz true node02
# Node03
apache-hive-1.2.1-bin.tar.gz true node03
apache-tez-0.9.1-bin.tar.gz true node03
sqoop-1.4.6.bin__hadoop-2.0.4-alpha.tar.gz true node03
yanagishima-18.0.zip true node03
# Muti
apache-flume-1.7.0-bin.tar.gz true node01,node02,node03
zookeeper-3.4.10.tar.gz true node01,node02,node03
kafka_2.11-0.11.0.2.tgz true node01,node02,node03
```

6. 如安装mysql、azkaban，需配置configs.txt，填写相关配置

```
# Mysql相关配置
mysql-root-password DBa2020*
mysql-hive-password DBa2020*
mysql-drive mysql-connector-java-5.1.26-bin.jar
# azkaban相关配置
azkaban-mysql-user root
azkaban-mysql-password DBa2020*
azkaban-keystore-password 123456
```

7. 进入systems目录执行batchOperate.sh脚本初始化环境

```
/home/hadoop/automaticDeploy/systems/batchOperate.sh
```

8. 进入hadoop目录中，选择对应组件的安装脚本，依次进行安装（需要在各个节点执行）

```
# 安装flume
/home/hadoop/automaticDeploy/systems/installFlume.sh
# 安装zookeeper
/home/hadoop/automaticDeploy/systems/installZookeeper.sh
# 安装kafka
/home/hadoop/automaticDeploy/systems/installKafka.sh
```

# 鸣谢
项目最初基于[BigData_AutomaticDeploy](https://github.com/SwordfallYeung/BigData_AutomaticDeploy)改进而来
