#include <Timer.h>
#include "MyCollection.h"
#include <printf.h>

module ManyToOneP{
	provides {
		interface ManyToOne;
	}
	uses {
		interface Timer<TMilli> as RetryForwardingTimer;
	   	interface Leds;
   		interface Boot;
		interface AMPacket;
		interface PacketLink;
		interface LowPowerListening as LPL;
		interface Random;
		interface CC2420Packet;
		interface SplitControl as AMControl;
		interface AMSend as DataSend;
   		interface Receive as DataReceive;
		interface Routing;
	}
}
implementation{
#define NUM_RETRIES 3
#define RESCHEDULING_SEND (4*1024L)
message_t data_output;
bool sending_data;
bool i_am_sink;
MyData tmp;

event void Boot.booted() {
	/* setting up the LPL layer */
	if (TOS_NODE_ID == 1)
		i_am_sink=TRUE;
	else
		i_am_sink=FALSE;
	call LPL.setLocalWakeupInterval(LPL_DEF_REMOTE_WAKEUP);
	call AMControl.start();
}

void send_data() {
	error_t err;
	uint8_t current_parent;
	call PacketLink.setRetries(&data_output, NUM_RETRIES); // important to set it every time
   	current_parent = call Routing.getParent();
	err = call DataSend.send(current_parent, &data_output, sizeof(CollectionData));
	if (err == SUCCESS)
		sending_data = TRUE;
	else{
		call RetryForwardingTimer.startOneShot(call Random.rand16() % RESCHEDULING_SEND);
		//TODO handle rescheduling
		sending_data = FALSE;}
}

event void DataSend.sendDone(message_t* msg, error_t error) {
	if(error != SUCCESS)
	{
		printf("[ERROR] DataSend sendDone failed, maybe we have to reschedule?\n");
	}
	sending_data = FALSE;
}

command void ManyToOne.send(MyData * d) {
	CollectionData* payload;
   
	if (sending_data)
	{
		tmp.seqn = d->seqn;
		call RetryForwardingTimer.startOneShot(call Random.rand16() %RESCHEDULING_SEND);
	}
	else{
	payload = call DataSend.getPayload(&data_output, sizeof(CollectionData));

	payload->hops = 0;
	payload->data = *d;
	payload->from = TOS_NODE_ID;
	send_data();
	}
}

event message_t* DataReceive.receive(message_t* msg, void* payload, uint8_t len) {
	CollectionData* payload_in = payload;
	
	if (i_am_sink) {
		signal ManyToOne.receive(payload_in->from, &payload_in->data);
	}
	else {
		CollectionData* payload_out;
		if (sending_data)
			return msg;

		payload_out = call DataSend.getPayload(&data_output, sizeof(CollectionData));
		
		sending_data = TRUE;
		memcpy(payload_out, payload_in, sizeof(CollectionData));
		payload_out->hops++;
		send_data();
	}
	return msg;
}

event void RetryForwardingTimer.fired() {
	//TODO: call forwarding info to root
	call ManyToOne.send(&tmp);

}
event void AMControl.startDone(error_t err) {
	if (err != SUCCESS) {
		call AMControl.start();   /* trying again */
	}
}


event void AMControl.stopDone(error_t err) {}

}
