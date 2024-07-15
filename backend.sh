#!/bin/bash

USERID=$(id -u)
TIMESTAMP=$(date +%F-%H-%M-%S)
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOGFILE=/tmp/$SCRIPT_NAME-$TIMESTAMP.log
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

echo "Please enter DB password:"
read -s mysql_root_password

VALIDATE(){
   if [ $1 -ne 0 ]
   then
        echo -e "$2...$R FAILURE $N"
        exit 1
    else
        echo -e "$2...$G SUCCESS $N"
    fi
}

if [ $USERID -ne 0 ]
then
    echo "Please run this script with root access."
    exit 1 # manually exit if error comes.
else
    echo "You are super user."
fi

dnf module disable nodejs -y &>>LOGFILE
VALIDATE $? "Disabling default nodejs"

dnf module enable nodejs:20 -y &>>LOGFILE
VALIDATE $? "Enabling nodejs 20 version"

dnf install nodejs -y &>>LOGFILE
VALIDATE $? "Installing nodejs"

#useradd expense &>>LOGFILE  #username same will not create so idempotency not required
#VALIDATE $? "Creating expense user"

id expense &>>LOGFILE
if [ $? -ne 0 ]
then    
    useradd expese &>>LOGFILE
    #VALIDATE $? "Creating expense user"
else
    echo -e "Expense user already created...$Y SKIPPING $N"
fi    

mkdir -p /app &>>LOGFILE  #-p validation checks 
VALIDATE $? "Creating app directory"

curl -o /tmp/backend.zip https://expense-builds.s3.us-east-1.amazonaws.com/expense-backend-v2.zip &>>LOGFILE
VALIDATE $? "Downloading backendend code"

cd /app
rm -rf /app/* #removing first everything in this folder
unzip /tmp/backend.zip &>>LOGFILE # will struck and ask for rezip so writing rm
VALIDATE $? "Extracted backendend code"

npm install &>>LOGFILE
VALIDATE $? "Installing Nodejs dependecies"

#vim /etc/systemd/system/backend.service vim is for our visual
cp /home/ec2-user/expense-shell/backend.service /etc/systemd/system/backend.service &>>LOGFILE
VALIDATE $? "copied backend service"

systemctl daemon-reload &>>LOGFILE
systemctl start backend &>>LOGFILE
systemctl enable backend &>>LOGFILE
VALIDATE $? "Sartind and enabling backend"

dnf install mysql -y &>>LOGFILE
VALIDATE $? "Installing mysql client"

#mysql -h <MYSQL-SERVER-IPADDRESS> -uroot -pExpenseApp@1 < /app/schema/backend.sql
mysql -h abhilash.store -uroot -p${mysql_root_password} < /app/schema/backend.sql &>>$LOGFILE
VALIDATE $? "Schema Loading"

systemctl restart backend &>>LOGFILE
VALIDATE $? "Restarting backend"
