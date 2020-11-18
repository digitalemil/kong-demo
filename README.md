![](https://github.com/digitalemil/kong-demo/blob/main/imgs/kongandkuma.png)

# A minimal Kong & Kuma Demo on Google Cloud Shell

All you need is a gmail account and a browser. Google Cloud Shell is free for every gmail user and does not need anything else (like setting up billing, credit card, etc.)

* In your browser go to: 
  + https://shell.cloud.google.com

* Clone this repo:
  + git clone https://github.com/digitalemil/kong-demo
  
* Start the installation:
  + kong-demo/kong-demo.sh

### Known Issues:
* postgres install hangs. If that happens just restart the script

* Grafana has no data. Run kubectl delete ns kuma-metrics and rerun the script installing Kuma again (or just the metrics)

