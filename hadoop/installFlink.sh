#! /bin/bash

function configureFlinkConf()
{
 flinkConfUrl=$1
 masterNode=$2
 
 # 配置主节点地址 
 jobmanager_node="jobmanager.rpc.address: $masterNode"
 sed -i "s/^jobmanager.rpc.address: localhost/$jobmanager_node/g" $flinkConfUrl
}

function configureMaster()
{
 flinkMasterConf=$1
 masterNode=$2

 sed -i "s/^localhost/$masterNode/g" $flinkMasterConf
}

function configureWorks()
{
 flinkWorkerConf=$1
 installNodes=$2
 
 sed -i '/^localhost/d' $flinkWorkerConf

 #遍历配置Flink Work节点
 OLD_IFS="$IFS" #保存旧的分隔符
 IFS=","
 nodes=($installNodes)
 IFS="$OLD_IFS" # 将IFS恢复成原来的
 for i in "${!nodes[@]}"; do
    echo "${nodes[i]}" >> $flinkWorkerConf
 done
}

function installFlink()
{
 #1.在frames.txt中查看是否需要安装flink
 flinkInfo=`egrep "^flink" ../frames.txt`

 flink=`echo $flinkInfo | cut -d " " -f1`
 isInstall=`echo $flinkInfo | cut -d " " -f2`
 flinkNodes=`echo $flinkInfo | cut -d " " -f3` 
 masterNode=`echo $flinkInfo | cut -d " " -f4` 
 node=`hostname`

 #是否安装
 if [[ $isInstall = "true" && $flinkNodes =~ $node ]];then
    
     #2.查看/opt/frames目录下是否有flink安装包
     flinkIsExists=`find /opt/frames -name $flink`

     if [[ ${#flinkIsExists} -ne 0 ]];then

          if [[ ! -d /opt/app ]];then
              mkdir /opt/app && chmod -R 775 /opt/app
          fi

          #删除旧的
          flink_home_old=`find /opt/app -maxdepth 1 -name "flink*"`
          for i in $flink_home_old;do
                rm -rf $i
          done

          #3.解压到指定文件夹/opt/app中
          echo "开始解压flink安装包"
          tar -zxvf $flinkIsExists -C /opt/app >& /dev/null
          echo "flink安装包解压完毕"

          flink_home=`find /opt/app -maxdepth 1 -name "flink*"`

          #4.配置flink-conf.yaml文件
          configureFlinkConf $flink_home/conf/flink-conf.yaml $masterNode

          #5.配置masters文件
          configureMaster $flink_home/conf/masters $masterNode

          #6.配置workers文件
          configureWorks $flink_home/conf/workers $flinkNodes

          #7.配置FLINK_HOME
          profile=/etc/profile
          sed -i "/^export FLINK_HOME/d" $profile
          echo "export FLINK_HOME=$flink_home" >> $profile

          #8.配置PATH
          sed -i "/^export PATH=\$PATH:\$FLINK_HOME\/bin/d" $profile
          echo "export PATH=\$PATH:\$FLINK_HOME/bin" >> $profile

          #9.更新/etc/profile文件
          source /etc/profile && source /etc/profile
     else
         echo "/opt/frames目录下没有flink安装包"
     fi
 else
     echo "Flink不允许安装在当前节点，请检查配置文件！"
 fi

}

installFlink
