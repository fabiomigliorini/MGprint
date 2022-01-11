#!/usr/bin/env node

const { exec } = require("child_process");
const fs = require('fs');
const axios = require("axios");

const chalk = require("chalk");
const boxen = require("boxen");

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
  // const msgBox = boxen( greeting, boxenOptions );
  // console.log(msgBox);
  // console.log(printer);

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
        data.options.forEach(function(option) {
          command = command + " -o " + option
        });

        command = command + " -n " + data.copies
        console.log(command);
        exec(command);

      }).catch(error => {
        console.log(error);
      });
  });

});


/*

const yargs = require("yargs");

*/
/*
const options = yargs
 .usage("Usage: -n <name>")
 .option("n", { alias: "name", describe: "Your name", type: "string", demandOption: true })
 .argv;

greeting = `Hello, ${options.name}!`;
console.log(greeting);
*/

/*
console.log("Here's a random joke for you:");

// const url = "https://icanhazdadjoke.com/";
// const url = "https://dummyapi.io/data/v1/user/60d0fe4f5311236168a109ca";
const url = "https://jsonplaceholder.typicode.com/todos/2";

axios.get(url, { headers: { Accept: "application/json" } })
   .then(res => {
     console.log(res.data.title);
   });

const Conf = require('conf');
const config = new Conf();

config.set('unicorn', '🦄');
console.log(config.get('unicorn'));
//=> '🦄'

// Use dot-notation to access nested properties
config.set('foo.bar', true);
console.log(config.get('foo'));
//=> {bar: true}

config.delete('unicorn');
console.log(config.get('unicorn'));
*/


// // Publish a message to the test channel
// channel.publish('greeting', 'hello');

// Subscribe to messages on channel
/*
channel.subscribe('greeting', function(message) {
  console.log('greeting');
  console.log(message.data);
});
*/
