const bcrypt = require('bcrypt'); // https://www.abeautifulsite.net/hashing-passwords-with-nodejs-and-bcrypt
const mysql = require("mysql")
const fs = require("fs")
const conf_file = "config.json"
const conf_default_values = '{\n\t"SQLHOST": "localhost",\n\t"SQLUSER": "username",\n\t"SQLPASS": "secretpass",\n\t"SQLDB": "overcast2_db",\n\t"SERVERADMINUSER": "Admin",\n\t"SERVERADMINPASS": "Ov3rC4stPas5_67!"\n}'
const sql_connect_fail = "Unable to Connect to SQL Server"
const sql_connect_success = "successfully Connected to SQL Server"






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
            console.log("TEST FOR CONFIG FILE")
            console.log("RUN MAIN HERE")
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
                const create_agents_table_sql = "CREATE TABLE " + config.SQLDB + ".agents ( `id` int(100) NOT NULL, `username` varchar(255) DEFAULT NULL, `computer` varchar(255) DEFAULT NULL, `version` varchar(255) DEFAULT NULL, `internal_ip` varchar(255) DEFAULT NULL, `external_ip` varchar(255) DEFAULT NULL, `has_jobs` tinyint(2) NOT NULL DEFAULT 0, `created_at` timestamp NOT NULL DEFAULT current_timestamp(), `checked_in` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(), `registered` tinyint(2) NOT NULL DEFAULT 0, `password` varchar(255) DEFAULT NULL, `handler_url` varchar(255) DEFAULT NULL, `sleep_time_ms` int(100) NOT NULL DEFAULT 3000, `created_by` int(100) NOT NULL DEFAULT 1, `killed` tinyint(2) NOT NULL DEFAULT 0 ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
                con.query(create_agents_table_sql, function (err, result) {
                    if (err) {
                        console.log(err)
                    } else {
                        console.log("Creating agents Table")
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
                                                "INSERT INTO " + config.SQLDB + ".job_types VALUES (2, 'Upload File');" +
                                                "INSERT INTO " + config.SQLDB + ".job_types VALUES (3, 'Reverse TCP Shell');" +
                                                "INSERT INTO " + config.SQLDB + ".job_types VALUES (4, 'Take Screenshot');" + 
                                                "INSERT INTO " + config.SQLDB + ".job_types VALUES (5, 'Upgrade Agent');"
                con.query(populate_job_types_sql, function (err, result) {
                    if (err) {
                        console.log(err)
                    } else {
                        console.log("Inserting Default Values In To job_types Table")
                        console.log("Values created")
                    }
                });     
                // Create users table         
                const create_users_table = "CREATE TABLE " + config.SQLDB + ".users ( `id` INT NOT NULL AUTO_INCREMENT , `username` VARCHAR(255) NOT NULL , `password` VARCHAR(255) NOT NULL , `role` INT(100) NOT NULL DEFAULT 9 , PRIMARY KEY (`id`)) ENGINE = InnoDB;"                 
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
                



                con.end()
                
            }
        })
    } catch (error) {
        console.log(error)
        console.log(sql_connect_fail)
        process.exit()
    }   
}

ProcessArgs()

