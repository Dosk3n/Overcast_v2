const express = require('express');
const db = require('../db')
const router = express.Router();
const bcrypt = require('bcrypt')
const crypto = require('crypto')


router.get('/', async (req, res, next) => {
    try {
        
        res.json({Online: true});

    } catch (error) {
        console.log(error);
        res.json({Online: false});
    }
});


// ##### AUTH #####
// Auth User
router.get('/auth/:username/:password', async (req, res, next) => {
    try {
        let user = await db.getuserbyname(req.params.username)
        if(bcrypt.compareSync(req.params.password, user.password)) {
            let auth_token = crypto.createHash('md5').update(Date.now() + req.params.username).digest("hex")
            if (await db.inserttoken(req.params.username, auth_token)) {
                res.json( { id: user.id, username: user.username, role: user.role } ) // Dont want to return the password hash so creating our own response
            } else {
                res.json({id: 0})
            }
        } else {
            res.json({id: 0})
        }
    } catch (error) {
        res.json({id: 0})
    }
});


// ##### AGENTS #####

// Get Agents
router.get('/agents/:token', async (req, res, next) => {
    try {
        if (await db.tokensbytoken(req.params.token)) {
            let results = await db.agents();
            res.json(results);
        } else {
            res.sendStatus(401);
        }
    } catch (error) {
        console.log(error);
        res.sendStatus(500);
    }
});

// Get Agent By ID
router.get('/agents/:token/:id', async (req, res, next) => {
    try {
        if (await db.tokensbytoken(req.params.token)) {
            let results = await db.agentsbyid(req.params.id);
            res.json(results);
        } else {
            res.json({id: 0});
        }
    } catch (error) {
        console.log(error);
        res.sendStatus(500);
    }
});

// Insert An Agent (Register Agent)
router.post('/agents', async (req, res, next) => {
    try {
        if (await db.tokensbytoken(req.body.token)) {
            let external_ip = res.connection.remoteAddress;
            passwordhash = bcrypt.hashSync(req.body.password, 10);
            let results = await db.insertagent(req.body.username, req.body.computer, req.body.version, req.body.internal_ip, external_ip, passwordhash, req.body.handler_url, req.body.sleep_time_ms, req.body.created_by, req.body.agent_type, req.body.killed);
            res.json({agentId: results.insertId});
        } else {
            res.json({agentId: 0});
        }
    } catch (error) {
        console.log(error);
        res.json({agentId: 0});
    }
});

// Update An Agent
router.put('/agents/:id', async (req, res, next) => {
    try {
        if (await db.tokensbytoken(req.body.token)) {
            let external_ip = res.connection.remoteAddress;
            let results = await db.updateagent(req.body.username, req.body.computer, req.body.version, req.body.internal_ip, external_ip, req.params.id);
            res.json({updated: 1});
        } else {
            res.json({updated: 0});
        }
    } catch (error) {
        console.log(error);
        res.json({updated: 0});
    }
});








// ##### TOKENS #####

//Get Tokens By ID
router.get('/tokens/:token', async (req, res, next) => {
    try {
        //await db.deleteoldtokens();
        let results = await db.tokensbytoken(req.params.token);
        if (results) {
            res.json(results);
        } else {
            res.json({id: 0})
        }

    } catch (error) {
        console.log(error);
        res.json({id: 0})
    }
});

// Delete All Old Tokens
router.delete('/tokens', async (req, res, next) => {
    try {
        let results = await db.deleteoldtokens();
        console.log(results)
        res.json({deleted: 1});
    } catch (error) {
        console.log(error);
        res.json({deleted: 0});
    }
});








module.exports = router;