# MGprint

Instalação Dependências

```
sudo apt install git nodejs npm supervisor --yes
```

Baixar fontes do Github
```
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

Conteudo MGprint.conf
```
[program:MGprint]
directory=/opt/MGprint/
user=usuario
command=node .
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/MGprint.log
redirect_stderr=true
```

Reiniciar Supervisor
```
sudo service supervisor stop
sudo service supervisor start
sudo tail -f /var/log/supervisor/MGprint.log 
```
