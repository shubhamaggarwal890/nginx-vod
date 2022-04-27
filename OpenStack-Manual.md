Ubuntu 20.04 LTS with OpenStack Ussuri

Two Nodes - Controller and Compute

Details - Controller - Ubuntu 20.04.04 LTS live server, 2VCPU, 4GB RAM, 100GB SATA, 192.168.122.110(provider)(enp1s0) and 10.0.0.110(management)(enp2s0) 
Details - Compute - Ubuntu 20.04.04 LTS live server, 2VCPU, 8GB RAM, 100GB SATA, 192.168.122.111(provider)(enp1s0) and 10.0.0.111(management)(enp2s0)


Add management network IP address to both controller and compute nodes in /etc/hosts file.  You must comment out or remove IP address such as 127.0.1.1 entry to prevent name resolution problems.

Verify the network connectivity on both nodes by pinging other node and also test internet connectivity by pinging some external website.
On compute node, 

ping -c 4 google.com
ping -c 4 controller

On controller node, 

ping -c 4 google.com
ping -c 4 compute

Let's install Network Time Protocol on controller node.

apt install -y chrony

Edit the /etc/chrony/chrony.conf file after installation and add following to the file

allow 10.0.0.0/24

Then restart the chrony service via following command

service chrony restart

While on the compute node, install NTP

apt install -y chrony

Edit the /etc/chrony/chrony.conf file after installation, where first comment out the pool <server name> iburst line and then add following to the file

server controller iburst

Then restart the chrony service via following command

service chrony restart

Verify the operation on compute node, by running the following command

chronyc sources

For Ubuntu 20.04 LTS, default OpenStack package is Ussuri, on both nodes install the openstack client using following command

apt install python3-openstackclient

OpenStack services uses SQL database to store relative information. The database is installed on controller node.

apt install mariadb-server python3-pymysql

On Controller node - Create and edit the /etc/mysql/mariadb.conf.d/99-openstack.cnf file and add following

[mysqld]
bind-address = <management controller ip address>

default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8

After this restart the database service using following command, all this on controller node

service mysql restart
mysql_secure_installation

Next we install Message queue, this is installed on controller node. We are using RabbitMQ as message queue

apt install rabbitmq-server
rabbitmqctl add_user openstack <RABBIT PASS>
rabbitmqctl set_permissions openstack ".*" ".*" ".*"

Next we install Memcached to cache tokens, this is installed on controller node.

apt install memcached python3-memcache

On Controller node - edit the /etc/memcached.conf file, replace -l 127.0.0.1  to -l <management controller ip address>

Restart the service

service memcached restart

Next we install Etcd, it is used to store key-value pair, similar to other services, etcd runs on controller node. Let's install it

apt install etcd

On Controller node - edit the /etc/default/etcd file and make the following changes

ETCD_NAME="controller"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-01"
ETCD_INITIAL_CLUSTER="controller=http://<managment controller ip address>:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://<managment controller ip address>:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://<managment controller ip address>:2379"
ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
ETCD_LISTEN_CLIENT_URLS="http://<managment controller ip address>:2379"

Resart the service after the above changes

systemctl enable etcd
systemctl restart etcd

We have installed the basic services of the openstack, many of these services were installed on controller node.
Now to fullfil the minimal deployment of OpenStack, we must install
 - keystone
 - glance
 - placement
 - nova
 - neutron
 - horizon

Let's start one by one, installation and configuration of Identity service of OpenStack i.e. Keystone, follow the following commands on controller node

mysql

#In the mysql shell
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '<KEYSTONE_DBPASS>';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '<KEYSTONE_DBPASS>';
exit;

Now we're out of the mysql shell, let's install keystone component and configure it, run the following command on controller node

apt install keystone

Edit the /etc/keystone/keystone.conf file and in the [database] section and in the [token] section make the following changes

[database]
connection = mysql+pymysql://keystone:<KEYSTONE_DBPASS>@controller/keystone

[token]
provider = fernet

After successfully making the changes, run the following command on controller node

su -s /bin/sh -c "keystone-manage db_sync" keystone


keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

keystone-manage bootstrap --bootstrap-password <ADMIN_PASS> --bootstrap-admin-url http://controller:5000/v3/ --bootstrap-internal-url http://controller:5000/v3/ --bootstrap-public-url http://controller:5000/v3/ --bootstrap-region-id RegionOne

After this let's configure the apache HTTP server, which was by default installed with keystone package, on the controller node, edit /etc/apache2/apache2.conf file with following configuration

ServerName controller

After the addition, restart the apache service using following command

service apache2 restart

export OS_USERNAME=admin
export OS_PASSWORD=ADMIN_PASS
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3

Controller node - Let's create some domain, projects, users and roles with this new OpenStack service keystone, run the following commands

openstack domain create --description "An Example Domain" example
openstack project create --domain default --description "Service Project" service
openstack project create --domain default --description "Demo Project" myproject

openstack user create --domain default --password-prompt myuser
openstack role create myrole
openstack role add --project myproject --user myuser myrole

Let's verify these operations if the openstack works with set password, all these commands needs to be run on controller node

unset OS_AUTH_URL OS_PASSWORD
openstack --os-auth-url http://controller:5000/v3 --os-project-domain-name Default --os-user-domain-name Default --os-project-name admin --os-username admin token issue
openstack --os-auth-url http://controller:5000/v3 --os-project-domain-name Default --os-user-domain-name Default --os-project-name myproject --os-username myuser token issue

Let's save these environment variables in a file and load whenever they are needed, create a file named admin-openrc and set the following values on controller node

export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=ADMIN_PASS
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2

Controller node - Create another file demo-openrc file and add the following content:

export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=myproject
export OS_USERNAME=myuser
export OS_PASSWORD=DEMO_PASS
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2

Provide the file with executable permissions, using following commands and then load it as follows

chmod u+x admin-openrc
. admin-openrc

Verify if your environment variable works by issuing following command on controller node - 

openstack token issue

With this we have successfully installed keystone service on our controller node.

Let's jump to the new service that is image, Glance service will be installed on the controller node, run the following commands

mysql

#in the mysql shell

CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'GLANCE_DBPASS';
exit;

Load the environment variables on controller node, by running the following command -
. admin-openrc

let's now create glance user using following command on controller node -

openstack user create --domain default --password-prompt glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image" image
openstack endpoint create --region RegionOne image public http://controller:9292
openstack endpoint create --region RegionOne image internal http://controller:9292
openstack endpoint create --region RegionOne image admin http://controller:9292

Let's now install the glance package on controller node - 

apt install glance

After the installation, edit the /etc/glance/glance-api.conf file and complete the following actions:

[database]
# ...
connection = mysql+pymysql://glance:GLANCE_DBPASS@controller/glance

In the [keystone_authtoken] and [paste_deploy] sections, configure Identity service access:

[keystone_authtoken]
# ...
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = glance
password = GLANCE_PASS

[paste_deploy]
# ...
flavor = keystone

In the [glance_store] section, configure the local file system store and location of image files:

[glance_store]
# ...
stores = file,http
default_store = file
filesystem_store_datadir = /var/lib/glance/images/

After all the configurations, run the following commands on controller node -

su -s /bin/sh -c "glance-manage db_sync" glance
service glance-api restart

. admin-openrc

wget http://download.cirros-cloud.net/0.5.2/cirros-0.5.2-x86_64-disk.img

glance image-create --name "cirros" --file cirros-0.5.2-x86_64-disk.img --disk-format qcow2 --container-format bare --visibility=public
glance image-list

This sums up the installation of glance service on controller node.
Let's install placement service on the controller node. Let's see what all commands we need to run, follow the commands -

mysql

#in the mysql shell

CREATE DATABASE placement;
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY 'PLACEMENT_DBPASS';
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY 'PLACEMENT_DBPASS';
exit;

Let's create the placement based configuration using openstack command, follow the commands on controller node -
. admin-openrc
openstack user create --domain default --password-prompt placement
openstack role add --project service --user placement admin
openstack service create --name placement --description "Placement API" placement
openstack endpoint create --region RegionOne placement public http://controller:8778
openstack endpoint create --region RegionOne placement internal http://controller:8778
openstack endpoint create --region RegionOne placement admin http://controller:8778

After that, run the placement packages, run the following command on controller node -

apt install placement-api

After the installation, Edit the /etc/placement/placement.conf file and complete the following actions:

[placement_database]
# ...
connection = mysql+pymysql://placement:PLACEMENT_DBPASS@controller/placement

[api]
# ...
auth_strategy = keystone

[keystone_authtoken]
# ...
auth_url = http://controller:5000/v3
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = placement
password = PLACEMENT_PASS

After editing the /etc/placement/placement.conf file, run the following command on controller node -

su -s /bin/sh -c "placement-manage db sync" placement
service apache2 restart

Now let's verify the installation of placement on controller node, run the following command -

. admin-openrc
placement-status upgrade check

The following commands require you to install python package to vrify the placement API, to do that first install pip on controller node

apt install python3-pip

After that install following package on controller node - 

pip install osc-placement

Now let's test the placement API on controller node, using following commands - 

openstack --os-placement-api-version 1.2 resource class list --sort-column name
openstack --os-placement-api-version 1.6 trait list --sort-column name

With this verification we have installed placement too on our controller node, let's follow up with installation of Nova service, the Nova service will be configured on both controller node and compute node, let's see what all commands need to be run and that too where - 

Let's start with the configuration of Nova on controller node -

mysql

#in the mysql shell

CREATE DATABASE nova_api;
CREATE DATABASE nova;
CREATE DATABASE nova_cell0;
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';
exit;

After coming out of mysql shell, run the following commands on controller node to create nova user on controller node and its endpoint APIs-

. admin-openrc
openstack user create --domain default --password-prompt nova
openstack role add --project service --user nova admin

openstack service create --name nova --description "OpenStack Compute" compute
openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1
openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1
openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1

Now let's install all the appropriate packages of nova on controller node - 

apt install nova-api nova-conductor nova-novncproxy nova-scheduler

After the successful installation, edit the /etc/nova/nova.conf file and complete the following actions:

[api_database]
# ...
connection = mysql+pymysql://nova:NOVA_DBPASS@controller/nova_api

[database]
# ...
connection = mysql+pymysql://nova:NOVA_DBPASS@controller/nova

[DEFAULT]
# ...
transport_url = rabbit://openstack:RABBIT_PASS@controller:5672/

[api]
# ...
auth_strategy = keystone

[keystone_authtoken]
# ...
www_authenticate_uri = http://controller:5000/
auth_url = http://controller:5000/
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = NOVA_PASS

[DEFAULT]
# ...
my_ip = 10.0.0.11

[vnc]
enabled = true
# ...
server_listen = $my_ip
server_proxyclient_address = $my_ip

[glance]
# ...
api_servers = http://controller:9292

[oslo_concurrency]
# ...
lock_path = /var/lib/nova/tmp

Due to a packaging bug, remove the log_dir option from the [DEFAULT] section.

[placement]
# ...
region_name = RegionOne
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://controller:5000/v3
username = placement
password = PLACEMENT_PASS

After editing the configuration file of nova on controller node, let's populate the database using following commands on controller node -

su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
su -s /bin/sh -c "nova-manage db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova

After all this is done, we have to restart the services earlier installed on controller node - 

service nova-api restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart


After the nova on controller node, time to install and configure a compute node with Nova, start with installation of following package on compute node -

apt install nova-compute

After the installation edit the configuration file i.e. /etc/nova/nova.conf file and complete the following actions:

[DEFAULT]
# ...
transport_url = rabbit://openstack:RABBIT_PASS@controller

[api]
# ...
auth_strategy = keystone

[keystone_authtoken]
# ...
www_authenticate_uri = http://controller:5000/
auth_url = http://controller:5000/
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = NOVA_PASS

[DEFAULT]
# ...
my_ip = COMPUTE_MANAGEMENT_INTERFACE_IP_ADDRESS

[vnc]
# ...
enabled = true
server_listen = 0.0.0.0
server_proxyclient_address = $my_ip
novncproxy_base_url = http://controller:6080/vnc_auto.html

[glance]
# ...
api_servers = http://controller:9292

[oslo_concurrency]
# ...
lock_path = /var/lib/nova/tmp

[placement]
# ...
region_name = RegionOne
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://controller:5000/v3
username = placement
password = PLACEMENT_PASS

This completes the configuration of openstack nova service on compute node, one thing before we complete the configuration, check if your compute node supports hardware acceleration for virtual machines.
We can do that using following command on compute node - 

egrep -c '(vmx|svm)' /proc/cpuinfo

If this command returns a value of one or greater, your compute node supports hardware acceleration which typically requires no additional configuration.

If this command returns a value of zero, your compute node does not support hardware acceleration and you must configure libvirt to use QEMU instead of KVM.

Edit the [libvirt] section in the /etc/nova/nova-compute.conf file as follows:

[libvirt]
# ...
virt_type = qemu

This finalizes the editing of nova on compute node, and now we can restart the nova service on compute node - 

service nova-compute restart

Let's verify if everything with nova is intact on controller node, run the following commands - 

. admin-openrc

openstack compute service list --service nova-compute
su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova


Perform these commands on the controller node.
. admin-openrc

openstack compute service list

openstack catalog list

openstack image list

nova-status upgrade check

This sums up the entire process of installation of nova of controller and compute node. Now let's look forward to the installation of neutron service, Similar to nova, neutron too will be installed on both controller and nova - 
Let's first install and configure the controller node for Neutron.

mysql

#in the mysql shell

CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'NEUTRON_DBPASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'NEUTRON_DBPASS';
exit;

We are out of the mysql shell and now let's create the neutron user using openstack on controller node -

. admin-openrc
openstack user create --domain default --password-prompt neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network

openstack endpoint create --region RegionOne network public http://controller:9696
openstack endpoint create --region RegionOne network internal http://controller:9696
openstack endpoint create --region RegionOne network admin http://controller:9696

We'll be setting up the provider networks for our setup of OpenStack neutron, to do that we have to install the following packages on controller node -

apt install neutron-server neutron-plugin-ml2 neutron-linuxbridge-agent neutron-dhcp-agent neutron-metadata-agent

Controller node - After the completion, let's edit the neutron conf file, that is /etc/neutron/neutron.conf file and complete the following actions:

[database]
# ...
connection = mysql+pymysql://neutron:NEUTRON_DBPASS@controller/neutron

[DEFAULT]
# ...
core_plugin = ml2
service_plugins =
transport_url = rabbit://openstack:RABBIT_PASS@controller
auth_strategy = keystone

[keystone_authtoken]
# ...
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = neutron
password = NEUTRON_PASS

[DEFAULT]
# ...
notify_nova_on_port_status_changes = true
notify_nova_on_port_data_changes = true

[nova]
# ...
auth_url = http://controller:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = nova
password = NOVA_PASS

[oslo_concurrency]
# ...
lock_path = /var/lib/neutron/tmp

Controller node - After the configuration of neutron conf file, let's configure the modular layer 2 plug-in, the file is /etc/neutron/plugins/ml2/ml2_conf.ini and complete the following actions:

[ml2]
# ...
type_drivers = flat,vlan
mechanism_drivers = linuxbridge
extension_drivers = port_security

[ml2_type_flat]
# ...
flat_networks = provider

[securitygroup]
# ...
enable_ipset = true

Controller node - Afyer the configuration of ml2 plugin, lets configure the Linux bridge agent, where we edit the /etc/neutron/plugins/ml2/linuxbridge_agent.ini file and complete the following actions:

[linux_bridge]
physical_interface_mappings = provider:CONTROLLER_PROVIDER_INTERFACE_NAME

[vxlan]
enable_vxlan = false

[securitygroup]
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

Ensure your Linux operating system kernel supports network bridge filters by verifying all the following sysctl values are set to 1, this can be done using following command:

sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables

To enable networking bridge support, typically the br_netfilter kernel module needs to be loaded. This can be done using following command - 

modprobe br_netfilter


Now let's edit another networking configuration, this time edit the /etc/neutron/dhcp_agent.ini file, which handles the DHCP agent and complete the following actions on controller node:

[DEFAULT]
interface_driver = linuxbridge
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata = true

In the configuration of controller node, we will configure the metadata agent, the file is /etc/neutron/metadata_agent.ini and here complete the following actions on controller node:

[DEFAULT]
nova_metadata_host = controller
metadata_proxy_shared_secret = METADATA_SECRET

We missed out on nova configuration with neutron earlier, we'll do it now on controller node, where the /etc/nova/nova.conf file is edited following actions are performed:

[neutron]
auth_url = http://controller:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = NEUTRON_PASS
service_metadata_proxy = true
metadata_proxy_shared_secret = METADATA_SECRET

After the configuration section, let's sync the database, using following command on controller node

su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

And after that restart the services -
service nova-api restart
service neutron-server restart
service neutron-linuxbridge-agent restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart


Install and configure compute node


apt install neutron-linuxbridge-agent

Edit the /etc/neutron/neutron.conf file and complete the following actions:

[DEFAULT]
# ...
transport_url = rabbit://openstack:RABBIT_PASS@controller

In the [database] section, comment out any connection options because compute nodes do not directly access the database.

[DEFAULT]
# ...
auth_strategy = keystone

[keystone_authtoken]
# ...
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = neutron
password = NEUTRON_PASS

[oslo_concurrency]
# ...
lock_path = /var/lib/neutron/tmp

Edit the /etc/neutron/plugins/ml2/linuxbridge_agent.ini file and complete the following actions:

[linux_bridge]
physical_interface_mappings = provider:PROVIDER_INTERFACE_NAME

[vxlan]
enable_vxlan = false

[securitygroup]
# ...
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

Ensure your Linux operating system kernel supports network bridge filters by verifying all the following sysctl values are set to 1:

net.bridge.bridge-nf-call-iptables
net.bridge.bridge-nf-call-ip6tables

To enable networking bridge support, typically the br_netfilter kernel module needs to be loaded. Check your operating system’s documentation for additional details on enabling this module.


Configure the Compute service to use the Networking service
Edit the /etc/nova/nova.conf file and complete the following actions:

[neutron]
# ...
auth_url = http://controller:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = NEUTRON_PASS

service nova-compute restart

service neutron-linuxbridge-agent restart

s section describes how to install and configure the dashboard on the controller node.

apt install openstack-dashboard

Edit the /etc/openstack-dashboard/local_settings.py file and complete the following actions:

OPENSTACK_HOST = "controller"
ALLOWED_HOSTS = ['one.example.com', 'two.example.com']

Do not edit the ALLOWED_HOSTS parameter under the Ubuntu configuration section.

ALLOWED_HOSTS can also be ['*'] to accept all hosts. This may be useful for development work, but is potentially insecure and should not be used in production. See the Django documentation for further information.

Configure the memcached session storage service:

SESSION_ENGINE = 'django.contrib.sessions.backends.cache'

CACHES = {
    'default': {
         'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
         'LOCATION': 'controller:11211',
    }
}

Enable the Identity API version 3:

OPENSTACK_KEYSTONE_URL = "http://%s:5000/identity/v3" % OPENSTACK_HOST

Enable support for domains:

OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True

Configure API versions:

OPENSTACK_API_VERSIONS = {
    "identity": 3,
    "image": 2,
    "volume": 3,
}

Configure Default as the default domain for users that you create via the dashboard:

OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "Default"

Configure user as the default role for users that you create via the dashboard:

OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"

If you chose networking option 1, disable support for layer-3 networking services:

OPENSTACK_NEUTRON_NETWORK = {
    ...
    'enable_router': False,
    'enable_quotas': False,
    'enable_ipv6': False,
    'enable_distributed_router': False,
    'enable_ha_router': False,
    'enable_lb': False,
    'enable_firewall': False,
    'enable_vpn': False,
    'enable_fip_topology_check': False,
}

Optionally, configure the time zone:

TIME_ZONE = "TIME_ZONE"


Add the following line to /etc/apache2/conf-available/openstack-dashboard.conf if not included.

WSGIApplicationGroup %{GLOBAL}

 systemctl reload apache2.service