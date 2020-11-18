#!/bin/bash
PWD=$(pwd)
SCRIPTDIR=$(dirname "$0")

cd $SCRIPTDIR

read -r -p "Install, start & prepare Postgres? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
    mkdir -p pgsql/data
    touch pgsql/logfile

    # Install Postgres
    sudo apt-get update
    sudo apt-get install postgresql
    sudo cp -r /etc/postgresql/13/main/* pgsql/data/
    sudo chown -R $USER:$USER pgsql
    chmod -R 777 pgsql
 
    sudo su - postgres -c "export PATH=$PATH:/usr/lib/postgresql/13/bin; postgres -D $PWD/pgsql/data >$PWD/pgsql/logfile 2>&1"
    sudo su - postgres -c "export PATH=$PATH:/usr/lib/postgresql/13/bin;psql -c \"CREATE USER kong;\""
    sudo su - postgres -c "export PATH=$PATH:/usr/lib/postgresql/13/bin;psql -c \"ALTER ROLE kong PASSWORD 'kong';\""
    sudo su - postgres -c "export PATH=$PATH:/usr/lib/postgresql/13/bin;createdb kong -O kong"
else
    echo Skipping Postgres install 
fi

read -r -p "Start minikube? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
    minikube start
else
    echo Skipping minikube start 
    echo Testing kubectl
    kubectl get nodes
fi

read -r -p "Install Kuma? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then    
    curl -L https://kuma.io/installer.sh | sh -
    cd kuma-*/bin
    ./kumactl install control-plane | kubectl apply -f -
    sleep 20
    kubectl port-forward svc/kuma-control-plane -n kuma-system 5681:5681 &> /tmp/kuma-portforward-output.log &
    sleep 10
    kubectl apply -f ../../metrics1.yaml
    sleep 10
    ./kumactl install metrics | kubectl apply -f -
    sleep 10
    kubectl apply -f ../../metrics2.yaml
    sleep 10
    kubectl port-forward svc/grafana -n kuma-metrics 3020:80 &> /tmp/kuma-metrics-portforward-output.log &
    cd $SCRIPTDIR
else
    echo Skipping minikube start 
fi


read -r -p "Clone & deploy demo app (TheGym) into minikube? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
    cd $SCRIPTDIR
    git clone https://github.com/digitalemil/thesimplegym
    kubectl apply -f namespace.yaml
    cd thesimplegym
    kubectl -n thegym apply -f thesimplegym.yaml
    kubectl -n thegym delete deployment loader
    cd ..
    kubectl -n thegym apply -f messagelistener-svc.yaml
    sleep 10
    export TARGET=$(minikube -n thegym service ui | grep '\- http' | sed 's/.*http:\/\//''/g')
    export APPPORT=$(echo $TARGET | sed 's/[0-9.]*://g')
    kubectl port-forward svc/ui -n thegym 8088:80 &> /tmp/thegym-portforward-output.log &
    echo App reachable at: $$TARGET
else
    echo Skipping demo app deployment
fi


read -r -p "Install & start Kong? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
    sudo apt-get install -y apt-transport-https curl lsb-core
    echo "deb https://kong.bintray.com/kong-deb `lsb_release -sc` main" | sudo tee -a /etc/apt/sources.list
    curl -o bintray.key https://bintray.com/user/downloadSubjectPublicKey?username=bintray
    sudo apt-key add bintray.key
    sudo apt-get update
    sudo apt-get install -y kong

    sudo kong config -c $PWD/kong.conf init

    sed 's#%KONGYML%#'"$PWD"'#g' kong.conf.template >kong.conf

    sudo kong migrations bootstrap -c $PWD/kong.conf

    sudo kong start -c $PWD/kong.conf
else
    echo Skipping demo app deployment
fi


read -r -p "Create Kong service & route? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
    export TARGET=$(minikube -n thegym service ui | grep '\- http' | sed 's/.*http:\/\//''/g')
    
    curl -i -X POST   --url http://localhost:8001/services/   --data 'name=thegym-service'   --data "url=http://$TARGET"
    curl -i -X POST   --url http://localhost:8001/services/thegym-service/routes   --data 'paths[]=/'
    echo
    echo Access the service on port 8000 on this cloud shell
else
    echo Skipping creating service & route
fi

read -r -p "Create Load? [y/N] " response
export LISTENER=http://$(minikube -n thegym service messagelistener-svc | grep '\- http' | sed 's/.*http:\/\//''/g')   
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
    cd $SCRIPTDIR/thesimplegym/microservice-loadgenerator
    export LISTENER=http://$(minikube -n thegym service messagelistener-svc | grep '\- http' | sed 's/.*http:\/\//''/g')
    echo MessageListener: $LISTENER
    nodemon npm start &> /tmp/loadgenerator.log
  else
    echo Skipping load creation at $LISTENER
fi
