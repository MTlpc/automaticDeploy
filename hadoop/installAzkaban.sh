#! /bin/bash

function getKeyStore()
{
  # 密码
  pass_word=$1
  
  #1.检测expect服务是否存在，不存在则使用yum安装expect
 expectIsExists=`rpm -qa | grep expect` 
 if [ -z $expectIsExists ]
 then
      yum -y install expect
 fi

 expect << EOF
      # 生成keystore
      spawn keytool -keystore keystore -alias jetty -genkey -keyalg RSA
        expect {
                #expect实现自动输入密码
                "*口令*" { send "$pass_word\n";exp_continue } 
                "*口令*" { send "$pass_word\n";exp_continue }
                "*姓氏*" { send "\n";exp_continue }
                "*名称*" { send "\n";exp_continue }
                "*名称*" { send "\n";exp_continue }
                "*名称*" { send "\n";exp_continue }
                "*名称*" { send "\n";exp_continue }
                "*地区代码*" { send "\n";exp_continue }
                "*正确*" { send "y\n";exp_continue }
                "*回车*" { send "\n";exp_continue }
                eof
        }
EOF
}

# /opt/app/azkaban/server/conf/azkaban.properties
function configureAzkabanWeb()
{
mysqlNode=$1
mysql_user=$2
mysql_password=$3
pass_word=$4

cat << EOF > /opt/app/azkaban/server/conf/azkaban.properties
#Azkaban Personalization Settings
#服务器UI名称,用于服务器上方显示的名字
azkaban.name=Hadoop
#描述
azkaban.label=My Local Azkaban
#UI颜色
azkaban.color=#FF3601
azkaban.default.servlet.path=/index
#默认web server存放web文件的目录
web.resource.dir=/opt/app/azkaban/server/web/
#默认时区,已改为亚洲/上海 默认为美国
default.timezone.id=Asia/Shanghai

#Azkaban UserManager class
user.manager.class=azkaban.user.XmlUserManager
#用户权限管理默认类（绝对路径）
user.manager.xml.file=/opt/app/azkaban/server/conf/azkaban-users.xml

#Loader for projects
#global配置文件所在位置（绝对路径）
executor.global.properties=/opt/app/azkaban/executor/conf/global.properties
azkaban.project.dir=projects

#数据库类型
database.type=mysql
#端口号
mysql.port=3306
#数据库连接IP
mysql.host={{mysql_node}}
#数据库实例名
mysql.database=azkaban
#数据库用户名
mysql.user={{db_username}}
#数据库密码
mysql.password={{db_password}}
#最大连接数
mysql.numconnections=100

# Velocity dev mode
velocity.dev.mode=false

# Azkaban Jetty server properties.
# Jetty服务器属性.
#最大线程数
jetty.maxThreads=25
#Jetty SSL端口
jetty.ssl.port=8443
#Jetty端口
jetty.port=8081
#SSL文件名（绝对路径）
jetty.keystore=/opt/app/azkaban/server/keystore
#SSL文件密码
jetty.password=$pass_word
#Jetty主密码与keystore文件相同
jetty.keypassword=$pass_word
#SSL文件名（绝对路径）
jetty.truststore=/opt/app/azkaban/server/keystore
#SSL文件密码
jetty.trustpassword=$pass_word

# Azkaban Executor settings
executor.port=12321

# mail settings
mail.sender=
mail.host=
job.failure.email=
job.success.email=

lockdown.create.projects=false

cache.directory=cache
EOF

sed -i "s/{{mysql_node}}/$mysqlNode/g" /opt/app/azkaban/server/conf/azkaban.properties
sed -i "s/{{db_username}}/$mysql_user/g" /opt/app/azkaban/server/conf/azkaban.properties
sed -i "s/{{db_password}}/$mysql_password/g" /opt/app/azkaban/server/conf/azkaban.properties

# 增加管理员用户
cat << EOF > /opt/app/azkaban/server/conf/azkaban-users.xml
<azkaban-users>
	<user username="azkaban" password="azkaban" roles="admin" groups="azkaban" />
	<user username="metrics" password="metrics" roles="metrics"/>
	<user username="admin" password="admin" roles="admin,metrics" />
	<role name="admin" permissions="ADMIN" />
	<role name="metrics" permissions="METRICS"/>
</azkaban-users>
EOF
}

# /opt/app/azkaban/executor/conf/azkaban.properties
function configureAzkabanExecutor()
{
mysqlNode=$1
mysql_user=$2
mysql_password=$3

cat << EOF > /opt/app/azkaban/executor/conf/azkaban.properties
#Azkaban
#时区
default.timezone.id=Asia/Shanghai

# Azkaban JobTypes Plugins
#jobtype 插件所在位置
azkaban.jobtype.plugin.dir=plugins/jobtypes

#Loader for projects
executor.global.properties=/opt/app/azkaban/executor/conf/global.properties
azkaban.project.dir=projects

database.type=mysql
mysql.port=3306
mysql.host={{mysql_node}}
mysql.database=azkaban
mysql.user={{mysql_user}}
mysql.password={{mysql_passwd}}
mysql.numconnections=100

# Azkaban Executor settings
#最大线程数
executor.maxThreads=50
#端口号(如修改,请与web服务中一致)
executor.port=12321
#线程数
executor.flow.threads=30
EOF

sed -i "s/{{mysql_node}}/$mysqlNode/g" /opt/app/azkaban/executor/conf/azkaban.properties
sed -i "s/{{mysql_user}}/$mysql_user/g" /opt/app/azkaban/executor/conf/azkaban.properties
sed -i "s/{{mysql_passwd}}/$mysql_password/g" /opt/app/azkaban/executor/conf/azkaban.properties
}


function installAzkaban()
{
 #1.在frames.txt中查看是否需要安装azkaban
 executorInfo=`egrep "azkaban-executor" /home/hadoop/automaticDeploy/frames.txt`
 sqlInfo=`egrep "azkaban-sql" /home/hadoop/automaticDeploy/frames.txt`
 webInfo=`egrep "azkaban-web" /home/hadoop/automaticDeploy/frames.txt`

 # 获取Mysql信息 
 mysqlNode=`egrep "^mysql-rpm-pack" /home/hadoop/automaticDeploy/frames.txt | cut -d " " -f3`
 mysqlUser=`egrep "^azkaban-mysql-user" /home/hadoop/automaticDeploy/configs.txt | cut -d " " -f2`
 mysqlPasswd=`egrep "^azkaban-mysql-password" /home/hadoop/automaticDeploy/configs.txt | cut -d " " -f2`

 executor=`echo $executorInfo | cut -d " " -f1`
#  sql=`echo $sqlInfo | cut -d " " -f1`
 web=`echo $webInfo | cut -d " " -f1`

 isExecutorInstall=`echo $executorInfo | cut -d " " -f2`
#  isSqlInstall=`echo $sqlInfo | cut -d " " -f2`
 isWebInstall=`echo $webInfo | cut -d " " -f2`
 
 #是否安装
 if [[ $isExecutorInstall = "true" && $isWebInstall = "true" ]];then
     
     #2.查看/opt/frames目录下是否有azkaban安装包
     executorIsExists=`find /opt/frames -name $executor`
    #  sqlInfoIsExists=`find /opt/frames -name $sql`
     webIsExists=`find /opt/frames -name $web`
    
     if [[ ${#executorIsExists} -ne 0 && ${#webIsExists} -ne 0 ]];then
           
          if [[ ! -d /opt/app ]];then
              mkdir /opt/app && chmod -R 775 /opt/app
          fi
   
          #删除旧的
          azkaban_home_old=`find /opt/app -maxdepth 1 -name "*azkaban*"`
          for i in $azkaban_home_old;do
                rm -rf $i
          done

          # 创建安装目录
          mkdir /opt/app/azkaban

          #3.解压到指定文件夹/opt/app中
          echo "开始解压azkaban安装包"
          tar -zxvf $executorIsExists -C /opt/app/azkaban >& /dev/null
          # tar -zxvf $sqlInfoIsExists -C /opt/app/azkaban >& /dev/null
          tar -zxvf $webIsExists -C /opt/app/azkaban >& /dev/null

          echo "azkaban安装包解压完毕"

          # 移动azkaban
          execPath=`find /opt/app/azkaban -maxdepth 1 -name "*executor*"`
          webPath=`find /opt/app/azkaban -maxdepth 1 -name "*web*"`
          mv $execPath /opt/app/azkaban/executor
          mv $webPath /opt/app/azkaban/server

          # sql脚本导入到mysql
          # node=`hostname`

          # sqlPath=`find /opt/app/azkaban/ -maxdepth 2 -name "*create-all-sql*"`

          # 如果在Mysql安装节点，进行导入
          # if [ $mysqlNode = $node ]
          # then
          #   export MYSQL_PWD='Asddsadsa310*'
          #   mysql --connect-expired-password -uroot -e "drop database azkaban;"
          #   mysql --connect-expired-password -uroot -e "create database azkaban;"
          #   mysql --connect-expired-password -uroot -e "use azkaban;source $sqlPath;"
          # fi

          # 生成秘钥
          azkaban_keystore=`egrep "^azkaban-keystore-password" /home/hadoop/automaticDeploy/configs.txt | cut -d " " -f2`
          getKeyStore $azkaban_keystore
          mv keystore /opt/app/azkaban/server/
 
          #4.配置azkaban
          configureAzkabanWeb $mysqlNode $mysqlUser $mysqlPasswd $azkaban_keystore

          configureAzkabanExecutor $mysqlNode $mysqlUser $mysqlPasswd

          #8.配置AZKABAN_HOME
          azkaban_home=`find /opt/app -maxdepth 1 -name "*azkaban*"`
          profile=/etc/profile
          sed -i "/^export AZKABAN_HOME/d" $profile
          echo "export AZKABAN_HOME=$azkaban_home" >> $profile

          #9.配置PATH
          sed -i "/^export PATH=\$PATH:\$AZKABAN_HOME\/server\/bin/d" $profile
          sed -i "/^export PATH=\$PATH:\$AZKABAN_HOME\/executor\/bin/d" $profile

          echo "export PATH=\$PATH:\$AZKABAN_HOME/server/bin" >> $profile
          echo "export PATH=\$PATH:\$AZKABAN_HOME/executor/bin" >> $profile

          #10.更新/etc/profile文件
          source /etc/profile && source /etc/profile
          echo "---------------------"
          echo "|  Azkaban安装成功！ |"
          echo "---------------------"          
     else
         echo "/opt/frames目录下没有azkaban安装包"
     fi
 else
     echo "azkaban不被允许安装"
 fi
}

installAzkaban
