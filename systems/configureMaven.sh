#! /bin/bash

function configureMaven()
{
 #1.在frames.txt中查看是否需要安装maven
 mvnInfo=`egrep "maven" /home/hadoop/automaticDeploy/frames.txt`
 
 mvn=`echo $mvnInfo | cut -d " " -f1`
 isInstall=`echo $mvnInfo | cut -d " " -f2`

 #是否安装
 if [[ $isInstall = "true" ]];then
 
    #2.查看/opt/frames目录下是否有maven安装包
    mvnIsExists=`find /opt/frames -name $mvn`
    
    if [[ ${#mvnIsExists} -ne 0 ]];then
        
        if [ -d /usr/lib/maven ];then
              rm -rf /usr/lib/maven
        fi
 
        mkdir /usr/lib/maven && chmod -R 777 /usr/lib/maven
   
        #2.解压到指定文件夹/usr/lib/maven中 
        echo "开启解压maven安装包"
        tar -zxvf $mvnIsExists -C /usr/lib/maven >& /dev/null
        echo "maven安装包解压完毕"

        mvn_home=`find /usr/lib/maven/ -maxdepth 1 -name "apache-maven*"`

        #3.配置国内镜像源
        num=`sed -n -e "/<mirrors>/=" $mvn_home/conf/settings.xml`
        sed -i "${num}a <mirror>" $mvn_home/conf/settings.xml
        sed -i "`expr $num + 1`a <id>aliyunmaven<\/id>" $mvn_home/conf/settings.xml
        sed -i "`expr $num + 2`a <mirrorOf>*<\/mirrorOf>" $mvn_home/conf/settings.xml
        sed -i "`expr $num + 3`a <name>阿里云公共仓库<\/name>" $mvn_home/conf/settings.xml
        sed -i "`expr $num + 4`a <url>https://maven.aliyun.com/repository/public<\/url>" $mvn_home/conf/settings.xml
        sed -i "`expr $num + 5`a <\/mirror>" $mvn_home/conf/settings.xml
        
        #4.在/etc/profile配置MVN_HOME
        profile=/etc/profile
        sed -i "/^export MVN_HOME/d" $profile
        echo "export MVN_HOME=$mvn_home" >> $profile
 
        #5.在/etc/profile配置PATH
        sed -i "/^export PATH=\$PATH:\$MVN_HOME\/bin/d" $profile
        echo "export PATH=\$PATH:\$MVN_HOME/bin" >> $profile

        #6.更新/etc/profile文件
        source /etc/profile && source /etc/profile
    else
         echo "/opt/frames目录下没有maven安装包"
    fi
 else
     echo "maven不允许被安装"
 fi
}

configureMaven
