#! /bin/bash

# 配置ZK一键启动脚本
function configZookeeperShell()
{
# 获取Zookeeper安装目录
zk_home=$1
nodes=$2

cat >> $zk_home/bin/zookeeper.sh <<EOF
#! /bin/bash

case \$1 in
"start"){
	for i in ${nodes[*]}
	do
		ssh \$i "source /etc/profile && $zk_home/bin/zkServer.sh start"
	done
	};;
"stop"){
	for i in ${nodes[*]}
	do
		ssh \$i "source /etc/profile && $zk_home/bin/zkServer.sh stop"
	done
	};;
esac

EOF

# 为脚本赋权
chmod +x $zk_home/bin/zookeeper.sh

}


function installZK()
{
  #1.在frames.txt中查看是否需要安装zk
  zkInfo=`egrep "^zookeeper" /home/hadoop/automaticDeploy/frames.txt`
 
  zk=`echo $zkInfo | cut -d " " -f1`
  isInstall=`echo $zkInfo | cut -d " " -f2`
  installNode=`echo $zkInfo | cut -d " " -f3`
  node=`hostname`

  #是否安装
  if [[ $isInstall = "true" && $installNode =~ $node ]];then
      
     #2.查看/opt/frames目录下是否有zk安装包
     zkIsExists=`find /opt/frames -name $zk`
     if [[ ${#zkIsExists} -ne 0 ]];then
         
        if [[ ! -d /opt/app ]];then
           mkdir /opt/app && chmod -R 775 /opt/app
        fi
  
        #删除旧的
        zk_home_old=`find /opt/app -maxdepth 1 -name "zookeeper*"`
        for i in $zk_home_old;do
             rm -rf $i
        done

        #解压到指定文件夹/opt/app中
        echo "开始解压zookeeper安装包"
        tar -zxvf $zkIsExists -C /opt/app >& /dev/null
        echo "zookeeper安装包解压完毕"
 
        zk_home=`find /opt/app -maxdepth 1 -name "zookeeper*"`
        
        #在zookeeper安装目录下创建data、logs文件夹
        mkdir -m 755 $zk_home/data
        mkdir -m 755 $zk_home/logs

        #编辑zoo.cfg文件
        zooUrl=$zk_home/conf/zoo.cfg
        cp $zk_home/conf/zoo_sample.cfg $zooUrl
        num_data=`sed -n -e "/^dataDir=\/tmp\/zookeeper/=" $zooUrl`
        sed -i 's/^dataDir=\/tmp\/zookeeper/#&/' $zooUrl
        sed -i "${num_data}a dataDir=${zk_home}/data" $zooUrl
        echo "" >> $zooUrl
        
        #遍历配置Zookeeper服务节点
        OLD_IFS="$IFS" #保存旧的分隔符
        IFS=","
        nodes=($installNode)
        IFS="$OLD_IFS" # 将IFS恢复成原来的
        for i in "${!nodes[@]}"; do
           echo "server.$i=${nodes[i]}:2888:3888" >> $zooUrl
           if [[ ${nodes[i]} = $node ]];then
             #在data文件夹下新建myid文件，myid的文件内容为
             echo "$i" > $zk_home/data/myid
           fi
        done

      #   echo "server.1=node01:2888:3888" >> $zooUrl
      #   echo "server.2=node02:2888:3888" >> $zooUrl
      #   echo "server.3=node03:2888:3888" >> $zooUrl

        #编辑日志输出类型和输出目录
        log4jUrl=$zk_home/conf/log4j.properties
        sed -i 's/^log4j.rootLogger=\${zookeeper.root.logger}/#&/' $log4jUrl
        num_log=`sed -n -e "/^#log4j.rootLogger=DEBUG, CONSOLE, ROLLINGFILE/=" $log4jUrl`
        sed -i "${num_log}a log4j.rootLogger=INFO, ROLLINGFILE" $log4jUrl
 
        sed -i 's/ZOO_LOG_DIR="."/ZOO_LOG_DIR="${zk_home}\/logs"/' $zk_home/bin/zkEnv.sh

        #配置Zookeeper一键启动脚本   
        configZookeeperShell $zk_home $nodes

        #配置ZOOKEEPER_HOME
        profile=/etc/profile
        sed -i "/^export ZOOKEEPER_HOME/d" $profile
        echo "export ZOOKEEPER_HOME=$zk_home" >> $profile

        #配置PATH
        sed -i "/^export PATH=\$PATH:\$ZOOKEEPER_HOME\/bin/d" $profile
        echo "export PATH=\$PATH:\$ZOOKEEPER_HOME/bin" >> $profile
 
        #更新/etc/profile文件
        source /etc/profile && source /etc/profile
     else
         echo "/opt/frames目录下没有Zookeeper安装包"
     fi
  else 
      echo "Zookeeper不允许被安装在当前节点"
  fi
}

installZK
