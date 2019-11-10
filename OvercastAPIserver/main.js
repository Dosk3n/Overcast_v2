/* 
MariaDB [overcast_db]> describe agents;
+---------------+---------------------+------+-----+---------+----------------+
| Field         | Type                | Null | Key | Default | Extra          |
+---------------+---------------------+------+-----+---------+----------------+
| id            | bigint(20) unsigned | NO   | PRI | NULL    | auto_increment |
| internal_ip   | varchar(45)         | NO   |     | NULL    |                |
| external_ip   | varchar(45)         | NO   |     | NULL    |                |
| user          | varchar(100)        | NO   |     | NULL    |                |
| computer_name | varchar(100)        | NO   |     | NULL    |                |
| status        | varchar(20)         | NO   |     | NULL    |                |
| created_at    | datetime            | NO   |     | NULL    |                |
| checked_in    | datetime            | NO   |     | NULL    |                |
| registered    | tinyint(1)          | NO   |     | NULL    |                |
| api_key       | varchar(34)         | NO   |     | NULL    |                |
| handler_url   | varchar(250)        | NO   |     | NULL    |                |
| sleep_time    | varchar(20)         | NO   |     | NULL    |                |
| killed        | tinyint(1)          | NO   |     | NULL    |                |
+---------------+---------------------+------+-----+---------+----------------+

MariaDB [overcast_db]> describe jobs;
+------------------+---------------------+------+-----+---------+----------------+
| Field            | Type                | Null | Key | Default | Extra          |
+------------------+---------------------+------+-----+---------+----------------+
| id               | bigint(20) unsigned | NO   | PRI | NULL    | auto_increment |
| agent_id         | int(11)             | NO   |     | NULL    |                |
| command          | text                | NO   |     | NULL    |                |
| command_response | text                | NO   |     | NULL    |                |
| complete         | tinyint(1)          | NO   |     | NULL    |                |
| job_fetched      | tinyint(1)          | NO   |     | NULL    |                |
| created_at       | timestamp           | YES  |     | NULL    |                |
| updated_at       | timestamp           | YES  |     | NULL    |                |
+------------------+---------------------+------+-----+---------+----------------+



*/




const mysql = require("mysql")
const fs = require("fs")
const ini = require('ini')
const conf_file = "config.json"
const conf_default_values = '{\n\t"SQLHOST": "localhost",\n\t"SQLUSER": "username",\n\t"SQLPASS": "secretpass",\n\t"SQLDB": "database"\n}'
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
            password: config.SQLPASS
        })
        con.connect(function(err) {
            if (err) {
                console.error(err)
                console.log(sql_connect_fail)
                process.exit()
            } else {
                console.log(sql_connect_success)
                // Attempt to drop the database if it already exists
                con.query("DROP DATABASE " + config.SQLDB + ";", function (err, result) {
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
                const create_agents_table_sql = "CREATE TABLE " + config.SQLDB + ".agents ( `id` int(100) NOT NULL, `username` varchar(255) DEFAULT NULL, `computer` varchar(255) DEFAULT NULL, `internal_ip` varchar(255) DEFAULT NULL, `external_ip` varchar(255) DEFAULT NULL, `has_jobs` tinyint(2) NOT NULL DEFAULT 0, `created_at` timestamp NOT NULL DEFAULT current_timestamp(), `checked_in` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(), `registered` tinyint(2) NOT NULL DEFAULT 0, `password` varchar(255) DEFAULT NULL, `handler_url` varchar(255) DEFAULT NULL, `sleep_time_ms` int(100) NOT NULL DEFAULT 3000, `killed` tinyint(2) NOT NULL DEFAULT 0 ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
                con.query(create_agents_table_sql, function (err, result) {
                    if (err) {
                        console.log(err)
                    } else {
                        console.log("Creating agents Table")
                        console.log("Table created")
                    }
                });
                con.end()
                console.log("Finished Setup. Please Restart")
            }
        })
    } catch (error) {
        console.log(error)
        console.log(sql_connect_fail)
        process.exit()
    }   
}

ProcessArgs()

