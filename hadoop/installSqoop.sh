#!/bin/bash

# Sqoop配置文件修改
function configureSqoopEnv()
{
 sqoopEnvUrl=$1
 sqoop_home=$2

 cp $sqoop_home/conf/sqoop-env-template.sh $sqoopEnvUrl

 profile=/etc/profile
 hadoop_home=`egrep "^export HADOOP_HOME=" $profile`
 hadoop_common_home=${hadoop_home/HADOOP_HOME/HADOOP_COMMON_HOME}
 hadoop_mapred_home=${hadoop_home/HADOOP_HOME/HADOOP_MAPRED_HOME}
 hive_home=`egrep "^export HIVE_HOME=" $profile`

 echo "$hadoop_common_home" >> $sqoopEnvUrl
 echo "$hadoop_common_home" >> $sqoopEnvUrl
 echo "$hadoop_mapred_home" >> $sqoopEnvUrl
}

function installSqoop()
{
 #1.在frames.txt中查看是否需要安装sqoop
 sqoopInfo=`egrep "sqoop" /home/hadoop/automaticDeploy/frames.txt`

 sqoop=`echo $sqoopInfo | cut -d " " -f1`
 isInstall=`echo $sqoopInfo | cut -d " " -f2`
 sqoopNode=`echo $sqoopInfo | cut -d " " -f3`
 node=`hostname`
 
 #是否安装
 if [[ $isInstall = "true" && $sqoopNode = $node ]];then
     
     #2.查看/opt/frames目录下是否有sqoop安装包
     sqoopIsExists=`find /opt/frames -name $sqoop`
    
     if [[ ${#sqoopIsExists} -ne 0 ]];then
           
          if [[ ! -d /opt/app ]];then
              mkdir /opt/app && chmod -R 775 /opt/app
          fi
   
          #删除旧的
          sqoop_home_old=`find /opt/app -maxdepth 1 -name "*sqoop*"`
          for i in $sqoop_home_old;do
                rm -rf $i
          done

          #3.解压到指定文件夹/opt/app中
          echo "开始解压sqoop安装包"
          tar -zxvf $sqoopIsExists -C /opt/app >& /dev/null
          echo "sqoop安装包解压完毕"

          sqoop_home=`find /opt/app -maxdepth 1 -name "*sqoop*"`
 
          #4.配置sqoop-env.sh文件
          configureSqoopEnv $sqoop_home/conf/sqoop-env.sh $sqoop_home
   
          #7.拷贝Mysql JDBC连接驱动
          mysqlDrive=`egrep "^mysql-drive" /home/hadoop/automaticDeploy/configs.txt | cut -d " " -f2 | sed s/\r//`
          # 判断驱动是否存在
          driveIsExists=`find /opt/frames/lib -name $mysqlDrive`
          if [[ ${#driveIsExists} -ne 0 ]];then
            cp /opt/frames/lib/$mysqlDrive $sqoop_home/lib/
          else
            echo "/opt/frames/lib目录下没有Mysql驱动"
          fi

          #8.配置SQOOP_HOME
          profile=/etc/profile
          sed -i "/^export SQOOP_HOME/d" $profile
          echo "export SQOOP_HOME=$sqoop_home" >> $profile

          #9.配置PATH
          sed -i "/^export PATH=\$PATH:\$SQOOP_HOME\/bin/d" $profile
          echo "export PATH=\$PATH:\$SQOOP_HOME/bin" >> $profile

          #10.更新/etc/profile文件
          source /etc/profile && source /etc/profile

          echo "--------------------"
          echo "|  Sqoop安装成功！  |"
          echo "--------------------"
     else
         echo "/opt/frames目录下没有sqoop安装包1"
     fi
 else
     echo "Sqoop不允许被安装在当前节点"
 fi

}

installSqoop