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
	#define RETRY_JITTER (3*1024L)
	message_t data_output;
	DataFromSink* queuedDestData;
	bool sending_data;
	void sendSinkData(DataFromSink* data);

	event void Boot.booted() {
		call AMControl.start();
		call LPL.setLocalWakeupInterval(LPL_DEF_REMOTE_WAKEUP);
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
		{
			printf("[ERROR] Path to %d not found\n",destNode);
			return;
		}
  		destData -> data = *d;
  		destData -> finalDest = destNode;
		for (i=0;i<MAX_ROUTE_LENGTH;i++) {
				destData -> destRoute[i] = pathToDestNode[i];
		}
		if(sending_data)
		{
			queuedDestData = destData;
			call RetryForwarding.startOneShot((call Random.rand16())% RETRY_JITTER);
		}
		else
		{
			sendSinkData(destData);
		}
	}

	void sendSinkData(DataFromSink* data) {
  		error_t status;
		DataFromSink* destData = call DataFromSinkSend.getPayload(&data_output, sizeof(DataFromSink));
		if (destData == NULL)
			printf("[ERROR] Something gone wrong with the payload creation \n");
  		destData -> finalDest = data -> finalDest;
  		destData -> data = data -> data;
  		memcpy(destData -> destRoute, data -> destRoute, sizeof(data->destRoute[0])*MAX_ROUTE_LENGTH);
		call PacketLink.setRetries(&data_output, NUM_RETRIES);
  		status = call DataFromSinkSend.send(destData -> destRoute[0] , &data_output, sizeof(DataFromSink));
  		if(status != SUCCESS) {
			printf("[ERROR] Send DataFromSink failed, rescheduling\n");
			queuedDestData = data;
			sending_data=FALSE;
			call RetryForwarding.startOneShot((call Random.rand16()) % RETRY_JITTER);
		}
		else
		{
			sending_data=TRUE;
		}
  	}

  	event void RetryForwarding.fired(){
  		sendSinkData(queuedDestData);
  	}

	event void DataFromSinkSend.sendDone(message_t* msg, error_t error){
		sending_data= FALSE;
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

		if (sending_data)
		{
			queuedDestData= receivedDataFromSink;
			call RetryForwarding.startOneShot(call Random.rand16() % RETRY_JITTER);
		}
		else{
			sending_data=TRUE;
			sendSinkData(receivedDataFromSink);
		}
		return msg;
	}


}
