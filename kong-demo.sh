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
 
    sudo su - postgres -c "export PATH=$PATH:/usr/lib/postgresql/13/bin; postgres -D $PWD/pgsql/data >$PWD/pgsql/logfile 2>&1 &kong"
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
    sudo ln -s ./kumactl /usr/local/bin/kumactl
    kubectl port-forward svc/kuma-control-plane -n kuma-system 5681:5681 &> kuma-portforward-output.log &
    sleep 10
    kumactl install metrics | kubectl apply -f -
    sleep 10
    kumactl apply -f metrics.yaml
    sleep 10
    kubectl port-forward svc/grafana -n kuma-metrics 3000:80 &> kuma-metrics-portforward-output.log &
else
    echo Skipping minikube start 
fi



read -r -p "Clone & deploy demo app (TheGym) into minikube? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
    git clone https://github.com/digitalemil/thesimplegym
    kubectl apply -f namespace.yaml
    cd thesimplegym
    kubectl -n thegym apply -f thesimplegym.yaml
    cd ..
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


#export TARGET=$(minikube -n thegym service ui | grep '\- http' | sed 's/.*http:\/\//''/g')
#curl -i -X POST   --url http://localhost:8001/services/   --data 'name=thegym-service'   --data "url=http://$TARGET"
#curl -i -X POST   --url http://localhost:8001/services/thegym-service/routes   --data 'paths[]=/'

#echo Access the service on port 8000 on this cloud shell
