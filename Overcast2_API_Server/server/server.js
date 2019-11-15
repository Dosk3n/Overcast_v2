const express = require('express');
const apiRouter = require('./routes');
const app = express();
const bodyParser = require('body-parser');
app.use(bodyParser.json()); // support json encoded bodies
app.use(bodyParser.urlencoded({ extended: true })); // support encoded bodies
const bcrypt = require('bcrypt'); // https://www.abeautifulsite.net/hashing-passwords-with-nodejs-and-bcrypt


app.use(express.json());

app.use('/api', apiRouter);

app.listen(process.env.PORT || '3000', () => {
    console.log(`Server is running on port: ${process.env.PORT || '3000'}`);
});