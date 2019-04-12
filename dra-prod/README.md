# GCP


## Создание нового проекта

1. Для начала потребуется выполнить след. действия в веб-интерфейсе/консоле гугла.
	1. [Создать новый проект](https://console.cloud.google.com/projectcreate)
	2. [Включить следующие API](https://cloud.google.com/endpoints/docs/openapi/enable-api)
		* Cloud Resource Manager API
		* Cloud SQL
		* Cloud SQL Admin API
		* Compute Engine API
		* Service Networking API

		_Можно сделать это командами **gcloud**_:   
		```
		gcloud services enable servicenetworking.googleapis.com
		gcloud services enable cloudresourcemanager.googleapis.com
		gcloud services enable compute.googleapis.com
		gcloud services enable sql-component.googleapis.com
		gcloud services enable sqladmin.googleapis.com
		gcloud services enable storage-component.googleapis.com
		```
	3. [Cоздать сервисные учетные записи](https://console.cloud.google.com/iam-admin/serviceaccounts) и ключи в JSON для них:
		* **tf** - [владелец проекта](https://cloud.google.com/resource-manager/docs/access-control-proj#using_predefined_roles) и [администратор объектов в gcp](https://cloud.google.com/iam/docs/understanding-roles#storage-roles)
		* **ro** - риоднли хостов и групп для динамик инвентори
		* **sql** - с [правом рулежкой базами](https://cloud.google.com/iam/docs/understanding-roles#cloud-sql-roles)

		_В теории можно заморочиться и точнее описать каждую из ролей, в том числе в виде комманд для *gcloud*.
		Имеет смысл при росте команд, работающий с GCP._   
		Файлы с ключами закинуть их в нужную папку, выдержав указанное ниже именование:   
		```
		mv ~/Downloads/dra-prod-1b71ec5412c0.json ~/.secrets/dra-prod-tf.json
		mv ~/Downloads/dra-prod-a35ac42c812b.json ~/.secrets/dra-prod-ro.json
		mv ~/Downloads/dra-prod-90a7c00db85d.json ~/.secrets/dra-prod-sql.json
		```
	4. [Создать в s3 bucket](https://console.cloud.google.com/storage/browser), с именем соответствующим имени проекта.
2. Cоздать где-то на внешке домен, который будем использовать, и [делегировать его на гуглец](https://support.cloudflare.com/hc/en-us/articles/360021357131-Delegating-Subdomains-Outside-of-Cloudflare)
3. Вручную заполнить [variables.tf](#variablestf)
4. Вручную заполнить `*.main.gcp` файл в [динамическом инвентори](https://gitlab.dra-d.com/dvps/inventory/blob/master/prod/prod.gcp.yml)   
	Описание `*.main.gcp` [тут](https://gitlab.dra-d.com/dvps/inventory/tree/1e467848ef5ca9f419c4175401ecf1c60e8507ca#prodnew_cabinet_londongcpyml)
5. Запустить инициализацию terraform:   
	`terraform init -backend-config='bucket=dra-prod' -backend-config='credentials="~/.secrets/dra-prod-tf.json"'`   
	где `dra-prod` - имя проекта, а `"~/.secrets/dra-prod-tf.json"` - путь к кредам с админским доступом.

6. Запустить раскатку инфраструктуры:   
	`TF_VAR_VPN_SECRET="my_secret_ipsec_psk" terraform apply`, где `my_secret_ipsec_psk` - ключ для ipsec-туннеля к старой части прода.   
	На приемной стороне ставится в ansible-переменной `ipsec_tunnel_secret`.


## Структура и описание файлов

```
.
├── db.tf
├── main.tf
├── network_common.tf
├── network_vpn.tf
├── provider.tf
├── variables.tf
└── modules
	└── cluster
		├── main.tf
		└── variables.tf
```


### provider.tf

_Не требует модификации._   
Настраивает [terraform-провайдер](https://www.terraform.io/docs/providers/google/index.html) для GCP и хранение [terraform-стэйтов](https://www.terraform.io/docs/state/remote.html) в [Google S3](https://www.terraform.io/docs/backends/types/gcs.html)   


### network_common.tf
_Не требует модификации._   
Создает:   

* Статические IP для VPN и NAT
* Роутер для работы NAT
* NAT-правило
* Сетевой пиринг для связи между SQL-серверами и хостами


### network_vpn.tf

_Не требует модификации._   
Создает:   

* FW-правила:   
```
resource "google_compute_firewall" "vpn_input_rule"
resource "google_compute_firewall" "tcp_input_rule"
```   

* Шлюз:   
`resource "google_compute_vpn_gateway" "tunnel_gateway_1"`   

* Правила проброса IPSEC-пакетов на шлюз:   
```
resource "google_compute_forwarding_rule" "fr_esp"
resource "google_compute_forwarding_rule" "fr_udp500"
resource "google_compute_forwarding_rule" "fr_udp4500"
```   

* 2 IPSEC-туннеля   
	Основной и резервный, подключаются к удаленным IP **tunnel.remote_ip1** и **tunnel.remote_ip2** соответственно:   
```
resource "google_compute_vpn_tunnel" "tunnel_1"
resource "google_compute_vpn_tunnel" "tunnel_2"
```   

* Маршрут для направление трафика к удаленному ДЦ через один из туннелей.   
	Туннель выбирается по **tunnel.active_tunnel_id**:   
`resource "google_compute_route" "tunnel_route_1"`   

* DNS-запись на IP шлюза:   
`resource "google_dns_record_set" "vpn-dns"`   


### db.tf

_Не требует модификации._   
Создает мастера и слэйвы баз данных, а так же днс-записи для них.

### main.tf

1) Создает у себя зону, которую мы делегировали ранее
2) Используется модули для созданий различных групп хостов с различными именами и настройками
3) Создает DNS-запись для балансировщиков, которую можно использовать в качестве proxy для ssh


### modules/cluster/main.tf

Содержит описания действий для группы приложений:
1) создание хоста
2) запихивание хоста в группу(не важно для ансибла, он рулит группами по тэгу labels.host_group, согласно описанию динамического инвентори)
3) создает DNS-запись на внутренний IP хоста.
4) создает метаданные хоста, кладет публичные части SSH-ключей на хост
5) скачивает и запускает пост-инсталл скрипт согласно `metadata_startup_script`


### variables.tf

_На данный файл создан симлинк в modules/cluster/variables.tf_   
Содержит настройки, которые требуется править вручную при переезде на новый проект:   

* **project.project_id** - идентификатор проекта GCP:   
	```"project_id" = "dra-new-cab-london"```

* **project.region** - регион в GCP:   
	```"region"     = "europe-west2"```

* **project.zone** - зона в регионе GCP:   
	```"zone"       = "a"```

* **project.host_image** - образ, который будет использоваться для создания новых серверов   
	```"host_image" = "centos-cloud/centos-7"```

* **project.dns_zone_fqdn** - полное имя DNS-зоны, которая будет делегирована на GCP   
	```"dns_zone_fqdn" = "draniki-test.dra.com."```

* **project.dns_zone_id** - id DNS-зоны внутри GCP   
	```"dns_zone_id"   = "draniki-test"```


* **postgres.instance_index** - индекс инстанса баз данных в GCP   
	Обычно не требует модификации. Нужно в тех случаях, когда возникали ошибки при создании инстанса баз, и [создание с тем же именем невозможно](https://cloud.google.com/sql/docs/mysql/delete-instance):   
	_You cannot reuse an instance name for up to a week after you have deleted an instance._   
	```"instance_index" = "8"```

* **postgres.master_type** - ресурсы для мастеров баз данных в GCP   
	```"master_type"    = "db-custom-4-8192"```

* **postgres.slave_count** - кол-во RO-слэйвов баз данных в GCP   
	```"slave_count"    = 1```

* **postgres.slave_type** - ресурсы для RO-слэйвов баз данных в GCP   
	```"slave_type"    = "db-custom-1-4096"```


* **ssh_keys** - ключи, которые будут автоматически добавлены на новые сервера   
	```
	variable "ssh_keys" {
	  default = <<EOF
	s.admin1:ssh-rsa AAAAB4NzaC1y...
	s.admin2:ssh-rsa AAAAB5NzaC1y...
	  EOF
	}
	```


* **tunnel.active_tunnel_id** - номер туннеля, который будет использоваться для отправки данных в удаленный ДЦ.   
	По умолчанию это "1", то есть основной туннель.   
	```"active_tunnel_id" = "1"```

* **tunnel.remote_ip1** - внешний IP основного туннеля, который размещен на первом хосте из инвентори-группы `vpn-server`   
	```"remote_ip1"       = "24.91.131.20"```

* **tunnel.remote_ip2** - внешний IP резервного туннеля, который размещен на втором хосте из инвентори-группы `vpn-server`   
	```"remote_ip2"       = "24.13.130.141"```

* **tunnel.remote_network** - локальная сеть старой части прода.   
	На приемной стороне ставится в ansible-переменной `ipsec_tunnel_local_network`.
	```"remote_network"   = "192.168.255.0/24"```
