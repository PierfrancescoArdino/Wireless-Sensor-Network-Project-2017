#include <Timer.h>
#include "MyCollection.h"
#include <math.h>
#include <AM.h>
#include <printf.h>
module OneToManyP {
	provides interface OneToMany;
	uses {
		interface Boot;
		interface Routing;
		
		interface Random;
		interface CC2420Packet;
		interface LowPowerListening as LPL;
		interface PacketLink;

		interface SplitControl as AMControl;
		interface AMPacket;
		interface AMSend as DataFromSinkSend;
		interface Receive as DataFromSinkReceive;

		interface Timer<TMilli> as RetryForwarding;

		interface Leds;
	}
}
implementation
{
	#define NUM_RETRIES 3
	#define RETRY_JITTER (5*1024L)
	uint8_t seq_no;
	message_t data_output;
	DataFromSink* queuedDestData;

	void sendSinkData(DataFromSink* data);
	
	event void Boot.booted() {
		call AMControl.start();
		call LPL.setLocalWakeupInterval(LPL_DEF_REMOTE_WAKEUP);
		call PacketLink.setRetries(&data_output, NUM_RETRIES);
	}

	event void AMControl.startDone(error_t err) {

	}

	event void AMControl.stopDone(error_t err) {
		printf("[WARNING] AMControl stopped");
	}

	command void OneToMany.send(MyData* d, uint8_t destNode){
		uint8_t i = 0;
		uint8_t *pathToDestNode = call Routing.getDestinationRoute(destNode);
		DataFromSink* destData = call DataFromSinkSend.getPayload(&data_output, sizeof(DataFromSink));
		if(pathToDestNode==NULL)
			return;
  		destData -> data = *d;
  		destData -> finalDest = destNode;
		for (i=0;i<MAX_ROUTE_LENGTH;i++) {
				destData -> destRoute[i] = pathToDestNode[i];
			
		}
		sendSinkData(destData);
	}

	void sendSinkData(DataFromSink* data) {
  		error_t status;
		DataFromSink* destData = call DataFromSinkSend.getPayload(&data_output, sizeof(DataFromSink));
		if (destData == NULL)
			printf("loooooooooool \n");
  		destData -> finalDest = data -> finalDest;
  		destData -> data = data -> data;
  //		destData -> destRoute = data -> destRoute;
  		memcpy(destData -> destRoute, data -> destRoute, sizeof(data->destRoute[0])*MAX_ROUTE_LENGTH);
		//printf("[DEBUG] Forwarding target pakcet for %d to %d\n",netCollData -> finalDestination,netCollData -> route[0]);
  		status = call DataFromSinkSend.send(destData -> destRoute[0] , &data_output, sizeof(DataFromSink));
  		if(status != SUCCESS) {
			printf("[ERROR] Send DataFromSink failed, retrying soon...\n");
			queuedDestData->finalDest = data -> finalDest;
			queuedDestData->data = data -> data;
			memcpy(queuedDestData -> destRoute, data -> destRoute,  MAX_ROUTE_LENGTH * sizeof(data->destRoute[0]));
			//			queuedDestData->destRoute = data -> destRoute;
			call RetryForwarding.startOneShot((call Random.rand16()) % RETRY_JITTER);
		}
  	}

  	event void RetryForwarding.fired(){
  		sendSinkData(queuedDestData);
  	}

	event void DataFromSinkSend.sendDone(message_t* msg, error_t error){
	}

	event message_t* DataFromSinkReceive.receive(message_t* msg, void* payload, uint8_t length) {
		DataFromSink* receivedDataFromSink = (DataFromSink*)payload;
		uint8_t i;
		printf("[INFO] Received a packet from the sink, the destination is %d \n", receivedDataFromSink->finalDest);
		if (length != sizeof(DataFromSink))
			return msg;
		if(TOS_NODE_ID != receivedDataFromSink->destRoute[0])
		{
			printf("[ERROR] The packet isn't for me, discard \n");
			return msg;
		}
		if(TOS_NODE_ID == (receivedDataFromSink -> finalDest) ) {
			MyData receivedMyData = receivedDataFromSink->data;
			signal OneToMany.receive(&receivedMyData);
			return msg;
		}

		for(i=1;i<MAX_ROUTE_LENGTH;i++)
		{
			receivedDataFromSink->destRoute[i-1] = receivedDataFromSink->destRoute[i];
		}

		sendSinkData(receivedDataFromSink);

		return msg;
	}


}