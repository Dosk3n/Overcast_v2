const mysql = require('mysql');

const pool = mysql.createPool({
    connectionLimit: 20,
    user: 'root',
    password: '',
    host: 'localhost',
    database: 'overcast2_db',
    port: '3306'
});

let ocsqldb = {};

// Auth

ocsqldb.getuserbyname = (username) => {
    return new Promise((resolve, reject) => {
        pool.query('SELECT * FROM users WHERE username = ?', [username], (err, results) => {
            if (err) {
                return reject(err);
            }
            
            return resolve(results[0]);
        });
    });
};

// Agents

ocsqldb.agentsbyid = (id) => {
    return new Promise((resolve, reject) => {
        pool.query('SELECT * FROM agents WHERE id = ?', [id], (err, results) => {
            if (err) {
                return reject(err);
            }
            
            return resolve(results[0]);
        });
    });
};

ocsqldb.agents = () => {
    return new Promise((resolve, reject) => {
        pool.query('SELECT * FROM agents', (err, results) => {
            if (err) {
                return reject(err);
            }
            
            return resolve(results);
        });
    });
};

ocsqldb.agentsbyid = (id) => {
    return new Promise((resolve, reject) => {
        pool.query('SELECT * FROM agents WHERE id IN (?)', [id], (err, results) => {
            if (err) {
                return reject(err);
            }
            
            return resolve(results[0]);
        });
    });
};

ocsqldb.insertagent = (username, computer, version, internal_ip, external_ip, passwordhash, handler_url, sleep_time_ms, created_by, agent_type, killed) => {
    return new Promise((resolve, reject) => {
        pool.query('INSERT INTO `agents` (`id`, `username`, `computer`, `version`, `internal_ip`, `external_ip`, `has_jobs`, `created_at`, `checked_in`, `registered`, `password`, `handler_url`, `sleep_time_ms`, `created_by`, `agent_type`, `killed`) VALUES (NULL, "?", "?", "?", "?", "?", 0, current_timestamp(), current_timestamp(), "1", "?", "?", "?", "?", "?", "?")', [username, computer, version, internal_ip, external_ip, passwordhash, handler_url, sleep_time_ms, created_by, agent_type, killed], (err, results) => {
            if (err) {
                return reject(err);
            }
            
            return resolve(results);
        });
    });
};

ocsqldb.updateagent = (username, computer, version, internal_ip, external_ip, agent_id) => {
    return new Promise((resolve, reject) => {
        
        pool.query("UPDATE `agents` SET `username` = ?, `computer` = ?, `version` = ?, `internal_ip` = ?, `external_ip` = ?, `checked_in` = current_timestamp() WHERE `agents`.`id` = ?", [username, computer, version, internal_ip, external_ip, agent_id], (err, results) => {
            if (err) {
                return reject(err);
            }
            return resolve(results);
        });
    });
};

// Tokens

ocsqldb.deleteoldtokens = () => {
    return new Promise((resolve, reject) => {
        pool.query('DELETE FROM `auth_tokens` WHERE auth_token_expire < current_timestamp()', (err, results) => {
            if (err) {
                return reject(err);
            }
            return resolve(results);
        });
    });
};

ocsqldb.tokensbytoken = (token) => {
    return new Promise((resolve, reject) => {
        pool.query('SELECT * FROM auth_tokens WHERE auth_token = ?', [token], (err, results) => {
            if (err) {
                return reject(err);
            }
            return resolve(results[0]);
        });
    });
};

ocsqldb.inserttoken = (user_id, token) => {
    return new Promise((resolve, reject) => {
        pool.query('INSERT INTO auth_tokens VALUES (null, ?, ?, current_timestamp() + INTERVAL 10 MINUTE)', [user_id, token], (err, results) => {
            if (err) {
                return reject(err);
            }
            return resolve(results);
        });
    });
};



module.exports = ocsqldb;