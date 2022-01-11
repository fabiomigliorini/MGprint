# MGprint

Instalação Dependências e Baixar fonte GitHub

```
sudo apt install git nodejs npm supervisor --yes
cd /opt/
sudo git clone https://github.com/fabiomigliorini/MGprint.git
sudo chown usuario.usuario /opt/MGprint/ -R
cd /opt/MGprint/
npm install
cp config.json.sample config.json
```

Configurar Impressoras disponíveis e chave do Ably
```
vi config.json
```

Configurar Supervisor para que esteja sempre rodando
```
sudo vi /etc/supervisor/conf.d/MGprint.conf
```

```
[program:MGprint]
directory=/opt/MGprint/
command=node .
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/MGprint.log
```

```
sudo service supervisor stop
sudo service supervisor start
```
