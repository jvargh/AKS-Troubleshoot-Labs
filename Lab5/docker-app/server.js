'use strict';

const express = require('express');

// Constants
const PORT = process.argv[2];
const HOST = process.argv[3];
// App
const app = express();
app.get('/', (req, res) => {
  res.send('Hello World - AKS Triage and Troubleshooting Labs');
});

app.listen(PORT, HOST, () => {
  console.log(`Running on http://${HOST}:${PORT}`);
});


