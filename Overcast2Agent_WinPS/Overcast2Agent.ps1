function Start-Agent {
    param(
            [Parameter(Mandatory=$true)] $Url,
            [Parameter(Mandatory=$true)] $ServerUser,
            [Parameter(Mandatory=$true)] $ServerPass,
            [Parameter(Mandatory=$true)] $Password
        )

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@

	
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    function Create-Agent($HandlerUrl, $ServerUser, $ServerPass, $Password)
    {
        $properties = @{
            ID = 0
            Username = "unknown"
            Computer = "unknown"
            Version = "0.01"
            InternalIP = "0.0.0.0"
            ExternalIP = "0.0.0.0"
            HasJobs = 0
            CreatedAt = "unknown"
            CheckedIn = "unknown"
            Registered = 0
            ServerUser = $ServerUser
            ServerPass = $ServerPass
            Password = $Password
            HandlerUrl = $HandlerUrl
            SleepTime = 5000
            CreatedBy = 0
            AgentType = 2
            Killed = 0
            AuthToken = ""
        }

        $object = New-Object -TypeName PSObject -Property $properties

        Add-Member -memberType ScriptMethod -InputObject $object -Name "ServerOnline" -Value {
            # Check to see if server is online
			try {
                $url = $this.HandlerUrl
                $response = Invoke-WebRequest -Uri $url -Method GET
                $responseobj = $response.Content | ConvertFrom-Json
                if ($responseobj.online -eq 1) {
                    return 1
                } else {
                    return 0
                }
            } 
            catch {
                return 0
            } 
        }   

        Add-Member -memberType ScriptMethod -InputObject $object -Name "Auth" -Value {
            # Check to see if server is online
            try {
                $url = $this.HandlerUrl + "/auth?username=" + $this.ServerUser + "&password=" + $this.ServerPass
                $response = Invoke-WebRequest -Uri $url -Method GET
                $responseobj = $response.Content | ConvertFrom-Json
                $this.CreatedBy = $responseobj.id
                $this.AuthToken = $responseobj.auth_token
                return 1
            } 
            catch {
                return 0
            } 
        } 

        Add-Member -memberType ScriptMethod -InputObject $object -Name "CheckAuth" -Value {
            # Check to see if server is online
            try {
                $url = $this.HandlerUrl + "/auth/check?auth_token=" + $this.AuthToken + "&user_id=" + $this.CreatedBy
                $response = Invoke-WebRequest -Uri $url -Method GET
                $responseobj = $response.Content | ConvertFrom-Json
                if ($responseobj.authenticated -eq 1) {
                    return 1
                } else {
                    return 0
                }
            } 
            catch {
                return 0
            } 
        } 

        Add-Member -memberType ScriptMethod -InputObject $object -Name "CheckIn" -Value {
            # Check to see if server is online
			try {
                $url = $this.HandlerUrl + "/agents/byid?auth_token=" + $this.AuthToken + "&user_id=" + $this.CreatedBy + "&agent_id=" + $this.ID
                $response = Invoke-WebRequest -Uri $url -Method GET
                $responseobj = $response.Content | ConvertFrom-Json
                if ($responseobj.id -eq $this.ID){
                    $this.HasJobs = $responseobj.has_jobs
                    $this.Registered = $responseobj.registered
                    $this.HandlerUrl = $responseobj.handler_url
                    $this.SleepTime = $responseobj.sleep_time_ms
                    $this.Killed = $responseobj.killed
                    return 1
                } else {
                    return 0
                }
            } 
            catch {
                return 0
            } 
        } 

        Add-Member -memberType ScriptMethod -InputObject $object -Name "Register" -Value {
			try {
                $postparams = @{
                    id = $this.ID
                    username = $this.Username
                    computer = $this.Computer
                    version = $this.Version
                    internal_ip = $this.InternalIP
                    external_ip = $this.ExternalIP
                    has_jobs = $this.HasJobs
                    registered = $this.Registered
                    password = $this.Password
                    handler_url = $this.HandlerUrl
                    sleep_time_ms = $this.SleepTime
                    created_by = $this.CreatedBy
                    agent_type = $this.AgentType
                    killed = $this.Killed
                    auth_token = $this.AuthToken
                }
                $posturl = $this.HandlerUrl + "/agents"
                $response = Invoke-WebRequest -Uri $posturl -Method POST -Body $postParams
                $responseobj = $response.Content | ConvertFrom-Json

                if ($responseobj.agentId -And $responseobj.agentId -gt 0) {
                    $this.ID = $responseobj.agentId
                    $this.registered = 1
                    return 1 # Returns 1 but not needed to be viewed atm
                } else {
                    $this.registered = 0
                    return 0
                } 
            } 
            catch {
                Start-Sleep -milliseconds 300
                $this.registered = 0
                return 0
            }
        }  

        Add-Member -memberType ScriptMethod -InputObject $object -Name "Update" -Value {
			try {
                $postparams = @{
                    id = $this.ID
                    username = $this.Username
                    computer = $this.Computer
                    version = $this.Version
                    internal_ip = $this.InternalIP
                    external_ip = $this.ExternalIP
                    has_jobs = $this.HasJobs
                    registered = $this.Registered
                    password = $this.Password
                    handler_url = $this.HandlerUrl
                    sleep_time_ms = $this.SleepTime
                    created_by = $this.CreatedBy
                    agent_type = $this.AgentType
                    killed = $this.Killed
                    auth_token = $this.AuthToken
                }
                $json = $postparams | ConvertTo-Json;
                $contentType = "application/json"
                $posturl = $this.HandlerUrl + "/agents"
                $response = Invoke-WebRequest -Uri $posturl -Method PUT -ContentType $contentType -Body $json
                $responseobj = $response.Content | ConvertFrom-Json
                return 1
            } 
            catch {
                Start-Sleep -milliseconds 300
                return 0
            }
        }  

        Add-Member -memberType ScriptMethod -InputObject $object -Name "GtSysDts" -Value {
            try {
                $this.InternalIP = (
                    Get-NetIPConfiguration |
                    Where-Object {
                        $_.IPv4DefaultGateway -ne $null -and
                        $_.NetAdapter.Status -ne "Disconnected"
                    }
                ).IPv4Address.IPAddress
                $this.Username = $env:UserName
                $this.Computer = $env:ComputerName
                return 1
            }
            catch {
                return 0
            }
        } 



        return $object
    }

    $agent = Create-Agent -Password $Password -HandlerUrl $Url -ServerUser $ServerUser -ServerPass $ServerPass
    # This will loop until killed is set to true
    "OVERCAST2 AGENT IS STARTING..."
    while($agent.Killed -eq 0)
    {
        "-------------------------------------------------------------------"
        # Check that the server responds before progressing
        "CHECKING IF SERVER IS ONLINE..."
        if ( $agent.ServerOnline() ){
            "SERVER IS ONLINE!"
            "CHECKING TO SEE IF AGENT IS ALREADY AUTHORISED WITH TOKEN..."
            if(!$agent.CheckAuth()){
                "AGENT DOES NOT HAVE A VALID TOKEN"
                # Agent is not curently authed so we need to "log in"
                "ATTEMPTING TO AUTHENTICATE WITH SERVER..."
                if($agent.Auth()) {
                    "AGENT AUTHENTICATED AND TOKEN SAVED"
                } else {
                    "UNABLE TO AUTHENTICATE AGENT! CHECK USERNAME & PASSWORD"
                }
            } else {
                "AGENT HAS A VALID AUTHENTICATION TOKEN!"
                "CHECKING TO SEE IF AGENT IS ALREADY REGISTERED WITH SERVER..."
                if (!$agent.Registered) {
                    "AGENT IS NOT REGISTERED!"
                    "ATTEMPTING TO REGISTER AGENT WITH THE SERVER FOR A VALID ID"
                    if($agent.Register()){
                        "AGENT HAS BEEN REGISTERED AND PROVIDED WITH A VALID ID"
                    } else {
                        "THERE WAS AN ISSUE REGISTERING THE AGENT WITH THE SERVER"
                    }
                } else {
                    "ATTEMPTING TO RETRIEVE SYSTEM INFORMATION AND APPLY TO AGENT DETAILS..."
                    if ($agent.GtSysDts()){
                        "SYSTEM INFORMATION UPDATED!"
                        "UPLOADING AGENT DETAILS TO SERVER..."
                        if($agent.Update()){
                            "UPLOAD SUCCESSFUL"
                            "ATTEMPTING TO CHECK IN TO RETRIEVE SERVER CHANGES / AGENT UPDATES..."
                            if($agent.CheckIn()){
                                "CHECKED IN & UPDATED AGENT DETAILS"
                                "CHECKING IF THERE ARE ANY JOBS FOR AGENT"
                                if($agent.HasJobs){
                                    "AGENT HAS JOBS WAITING TO BE RETRIEVED"
                                } else {
                                    "NO JOBS TO BE RETRIEVED"
                                }
                            } else {
                                "WAS UNABLE TO CHECK IN SO NO UPDATED DETAILS WERE RETURNED"
                            }
                        } else {
                            "UPLOAD FAILED FAILED"
                        }
                    } else {
                        "UNABLE TO GET SYSTEM INFORMATION"
                    }
                }
            }
        } else {
            "UNABLE TO CONNECT TO SERVER!"
        }
        
        Start-Sleep -milliseconds $agent.SleepTime
    }


}
Start-Agent -Url "http://localhost:3003" -ServerUser "Admin" -ServerPass "Ov3rC4stPas5_67!" -Password "AgentPassword!"