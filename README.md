# MGprint

Servidor de impressão da MG Papelaria. Roda em cada computador que tem impressoras conectadas, escuta eventos de impressão do ERP via [Ably](https://ably.com/) e manda os PDFs pro CUPS.

## Como funciona

1. O ERP publica um evento no canal `printing` do Ably com o nome da impressora, URL do PDF, número de cópias e opções do `lp`.
2. O MGprint, em cada máquina, está inscrito nos eventos das impressoras listadas em `config.json`.
3. Ao receber um evento, baixa o PDF em `/tmp/` e executa `lp -d <impressora> <arquivo> -o <opcoes> -n <copias>`.

Código principal: [bin/index.js](bin/index.js).

## Instalação

Em Ubuntu 24.04+ (exige Node >=16):

```bash
curl -fsSL https://raw.githubusercontent.com/fabiomigliorini/MGprint/main/instalar.sh | bash
```

O script instala as dependências (git, nodejs, npm, supervisor), clona o projeto em `/opt/MGprint`, roda `npm install`, configura o supervisor pra manter o serviço sempre rodando e reinicia tudo.

Na primeira execução ele cria `config.json` a partir do sample. **Edite antes do serviço funcionar**:

```bash
sudo vi /opt/MGprint/config.json
```

Preencha:
- `ably.key` — chave de API do Ably
- `printers` — lista com os nomes das impressoras **exatamente como aparecem no CUPS**

Depois, reinicie:

```bash
sudo service supervisor restart
sudo tail -f /var/log/supervisor/MGprint.log
```

## Atualização

O mesmo script é idempotente — se o projeto já existe, ele faz `git pull`, reinstala dependências e reinicia o supervisor:

```bash
curl -fsSL https://raw.githubusercontent.com/fabiomigliorini/MGprint/main/instalar.sh | bash
```

Ou localmente:

```bash
bash /opt/MGprint/instalar.sh
```

## Sincronia de nomes de impressora com o servidor

Os nomes em `config.json` precisam bater com os do arquivo de impressoras do ERP, no servidor principal:

```bash
sudo vi /opt/www/MGspa/laravel/printers.json
```
