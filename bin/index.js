#!/usr/bin/env node

const { exec } = require("child_process");
const fs = require('fs');
const axios = require("axios");

const chalk = require("chalk");
const boxen = require("boxen");

// desenha caixa bonita de saudacao
let greeting = chalk.white.bold("MGprint - Servidor de Impressao MG Papelaria!");
const boxenOptions = {
 padding: 1,
 margin: 0,
 borderStyle: "round",
 borderColor: "green",
 backgroundColor: "#555555"
};
const msgBox = boxen( greeting, boxenOptions );
console.log(msgBox);

// importa arquivo de configuracao (config.json)
var rawdata = fs.readFileSync('config.json');
var config = JSON.parse(rawdata);

// conecta no servidor ably
var ably = new require('ably').Realtime(config.ably.key);
var channel = ably.channels.get(config.ably.channel);

// para cada printer do config.json
config.printers.forEach(function(printer) {

  // loga o Nome da printer
  let greeting = chalk.white.bold("Escutando eventos da impressora '" + printer + "'!");
  console.log(greeting);

  // Subscreve com o nome de cada printer, como nome de um evento
  channel.subscribe(printer, function(message) {

    // interpreta o json recebido
    var data = JSON.parse(message.data);
    console.log(printer);
    console.log(data);

    // faz o download da url com o pdf pra imprimir
    axios.request({
      'url': data.url,
      'method': data.method,
      responseType: "stream"
    }).then(response => {

        // salva arquivo no /tmp/
        let file = "/tmp/MGprint-" + new Date().toISOString() + ".pdf";
        console.log(file);
        response.data.pipe(fs.createWriteStream(file));

        // monta o comando de impressao
        var command = "lp -d " + printer + " " + file;

        // adiciona argumentos
        data.options.forEach(function(option) {
          command = command + " -o " + option
        });

        // adiciona numero de copias
        command = command + " -n " + data.copies
        console.log(command);

        // executa
        exec(command);

      }).catch(error => {
        console.log(error);
      });
  });

});
