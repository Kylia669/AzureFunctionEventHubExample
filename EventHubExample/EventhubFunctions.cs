using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Azure.Messaging.EventHubs;
using Microsoft.AspNetCore.Http;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;

namespace EventHubExample
{
    public class EventhubFunctions
    {
        private const string HubConnection = "hubConnection";
        private const string EventHubName = "akyleventhub";
        private ILogger<EventhubFunctions> _logger;

        public EventhubFunctions(ILogger<EventhubFunctions> logger)
        {
            _logger = logger;
        }


        [FunctionName("EventHubTrigger")]
        public async Task ConsumeEventAsync([EventHubTrigger(EventHubName, Connection = HubConnection)] EventData[] events)
        {
            var exceptions = new List<Exception>();

            foreach (EventData eventData in events)
            {
                try
                {
                    _logger.LogInformation($"C# Event Hub trigger function processed a message: {eventData.EventBody}");
                    await Task.Yield();
                }
                catch (Exception e)
                {
                    exceptions.Add(e);
                }
            }

            if (exceptions.Count > 1)
                throw new AggregateException(exceptions);

            if (exceptions.Count == 1)
                throw exceptions.Single();
        }


        [FunctionName("EventHubOutput")]
        [return: EventHub(EventHubName, Connection = HubConnection)]
        public SystemEvent ProduceEventAsync([HttpTrigger(Microsoft.Azure.WebJobs.Extensions.Http.AuthorizationLevel.Anonymous, "POST", Route = "produce")] HttpRequest req)
        {
            _logger.LogInformation($"Eventhub producer function executed at: {DateTime.UtcNow}");
            return new SystemEvent("Test", DateTime.UtcNow);
        }
    }

    public record SystemEvent(string Message, DateTime Date);
}
