#! /bin/bash

# 配置yanagishima
function configureYanagishima()
{
 yanagishimaUrl=$1
 prestoNode=$2
 
cat << EOF > $yanagishimaUrl
jetty.port=7080
presto.datasources=presto
presto.coordinator.server.presto=http://{prestoNode}:8080
catalog.presto=hive
schema.presto=default
sql.query.engines=presto
EOF

sed -i "s#{prestoNode}#$prestoNode#g" $yanagishimaUrl
}

function installyanagishima()
{
 #1.在frames.txt中查看是否需要安装yanagishima
 yanagishimaInfo=`egrep "yanagishima" /home/hadoop/automaticDeploy/frames.txt`
 prestoInfo=`egrep "presto" /home/hadoop/automaticDeploy/frames.txt`

 yanagishima=`echo $yanagishimaInfo | cut -d " " -f1`
 isInstall=`echo $yanagishimaInfo | cut -d " " -f2`
 installNode=`echo $yanagishimaInfo | cut -d " " -f3`
 prestoNode=`echo $prestoInfo | cut -d " " -f3`
 node=`hostname`
 
 #是否安装
 if [[ $isInstall = "true" && $installNode = $node ]];then
     
     #2.查看/opt/frames目录下是否有yanagishima安装包
     yanagishimaIsExists=`find /opt/frames -name $yanagishima`
    
     if [[ ${#yanagishimaIsExists} -ne 0 ]];then
           
          if [[ ! -d /opt/app ]];then
              mkdir /opt/app && chmod -R 775 /opt/app
          fi
   
          #删除旧的
          yanagishima_home_old=`find /opt/app -maxdepth 1 -name "*yanagishima*"`
          for i in $yanagishima_home_old;do
                rm -rf $i
          done

          #3.解压到指定文件夹/opt/app中
          echo "开始解压yanagishima安装包"
          unzip -d /opt/app $yanagishimaIsExists >& /dev/null
          echo "yanagishima安装包解压完毕"

          yanagishima_home=`find /opt/app -maxdepth 1 -name "*yanagishima*"`
 
          #4.配置yanagishima.properties文件
          configureYanagishima $yanagishima_home/conf/yanagishima.properties $prestoNode
          
          # 创建数据保存目录   
          mkdir $yanagishima_home/conf/data

          #8.配置yanagishima_HOME
          profile=/etc/profile
          sed -i "/^export YANA_HOME/d" $profile
          echo "export YANA_HOME=$yanagishima_home" >> $profile

          #9.配置PATH
          sed -i "/^export PATH=\$PATH:\$YANA_HOME\/bin/d" $profile
          echo "export PATH=\$PATH:\$YANA_HOME/bin" >> $profile

          #10.更新/etc/profile文件
          source /etc/profile && source /etc/profile

          # 输出提示信息
          echo "-----------------------"
          echo "| yanagishima安装成功! |"
          echo "-----------------------"
          echo "yanagishima服务端口为：7080"

     else
         echo "/opt/frames目录下没有yanagishima安装包"
     fi
 else
     echo "yanagishima不允许被安装在当前节点"
 fi
}

installyanagishima
