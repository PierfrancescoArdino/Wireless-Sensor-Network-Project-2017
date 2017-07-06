#include <Timer.h>
#include "MyCollection.h"
#include <printf.h>

module RoutingP {
  provides {
    interface Routing;
  }
  uses {
    interface Timer<TMilli> as RefreshTimer;
    interface Timer<TMilli> as NotificationTimer;
	interface Timer<TMilli> as InfoTimer;
	interface Timer<TMilli> as InfoTimerRescheduling;
	interface Timer<TMilli> as PrintRoutingTableTimer;
    interface Leds;
    interface Boot;
    interface AMPacket;
	interface PacketLink;
    interface AMSend as BeaconSend;
	interface AMSend as InfoToRootSend; 
    interface Receive as BeaconReceive;
	interface Receive as InfoToRootReceiver;
    interface CC2420Packet;
	interface SplitControl as AMControl;
    interface Random;
	interface LowPowerListening as LPL;
  }
}

implementation {
	
#define NUM_RETRIES 3
#define RSSI_THRESHOLD (-90)
#define REBUILD_PERIOD (120*1024L) //exactly 120 seconds, 1024 ticks per second in TinyOS 
#define PRINTROUTINGTABLE_PERIOD (100*1024L)
#define MAX_METRIC 65535U
#define MAX_NODES 30
#define BEACON_PERIOD (120*1024L)
#define BEACON_REPEAT_RESCHEDULING (3*1024L)           
#define BEACON_REPEAT_PERIOD (1*1024L)           
#define BEACON_INFO_TIME (15*1024L)
#define BEACON_INFO_RESCHEDULING (5*1024L)	
message_t beacon_output;
message_t data_output;
message_t info_output;
bool sending_beacon;
bool sending_data;
bool sending_info;
bool i_am_sink;
uint16_t current_seq_no;
uint16_t current_parent;
uint16_t current_hops_to_sink = MAX_METRIC; 
uint16_t num_received;
uint8_t routingTableIndex;
int current_rssi_to_parent; 
RoutingTableStruct routingTable[MAX_NODES];
RoutingTableStruct infoBeaconToReschedule;
bool checkIfNodeInroutingTable(uint8_t child, uint8_t father);
void createInfoBeacon(uint8_t child_address, uint8_t father_address);
void sendInfoBeacon();
task void send_beacon();

event void Boot.booted() {
	current_parent = TOS_NODE_ID;
	routingTableIndex=0;
	/* setting up the LPL layer */
	call LPL.setLocalWakeupInterval(LPL_DEF_REMOTE_WAKEUP);
	call AMControl.start();
}

command uint8_t Routing.getParent(){
	return current_parent;
}


command void Routing.buildTree() {
	i_am_sink = TRUE;
	current_hops_to_sink = 0;
	post send_beacon();
	call RefreshTimer.startPeriodic(REBUILD_PERIOD);
	call PrintRoutingTableTimer.startPeriodic(PRINTROUTINGTABLE_PERIOD);
}

task void send_beacon(){
	if (!sending_beacon) {
		error_t err;
		CollectionBeacon* msg = (CollectionBeacon*) (call BeaconSend.getPayload(&beacon_output, sizeof(CollectionBeacon)));
		msg->seq_no = current_seq_no;
		msg->metric = current_hops_to_sink;
		/*     printf("routing:NOT SEQ %u COST %u\n", current_seq_no, current_hops_to_sink); */
		err = call BeaconSend.send(AM_BROADCAST_ADDR, &beacon_output, sizeof(CollectionBeacon));
		if (err == SUCCESS){
			call Leds.led2On();
			sending_beacon = TRUE;
		} 
		else {
	//		printf("routing:\n\n\n\nERROR %u\n", err);
			// retry after a random time
			call NotificationTimer.startOneShot(call Random.rand16()% BEACON_REPEAT_RESCHEDULING);
		}
	}
}

event void RefreshTimer.fired() {
	if (!sending_beacon){
		current_seq_no++;
		post send_beacon();
	}
}

event void NotificationTimer.fired() {
	if (!sending_beacon){
		post send_beacon();
	}
}

event void BeaconSend.sendDone(message_t* msg, error_t error) {
	call Leds.led2Off();
	sending_beacon = FALSE;
	if (error != SUCCESS) {
		// retry sending the notification
		call NotificationTimer.startOneShot(call Random.rand16()%BEACON_REPEAT_RESCHEDULING);
	}
}

event void InfoToRootSend.sendDone(message_t* msg, error_t error)
{
	if (error == TRUE)
	{
		printf("SEND DONE FAILED I'M NODE %d and my parent is %d\n", TOS_NODE_ID, current_parent); 
	}
	sending_info = FALSE;
	//TODO: implement send done, check if send done succeded
}
int getRssi(message_t* msg){
	int rssi = (int8_t)call CC2420Packet.getRssi(msg) - 45; 
	// or CC2420Packet.getLqi(msg);
	return rssi;
}

void updateParent(uint16_t new_parent, uint16_t new_hops_to_sink, int new_rssi_to_parent) {
    current_parent=new_parent;
    current_hops_to_sink=new_hops_to_sink; 
    current_rssi_to_parent=new_rssi_to_parent; 
   // printf("routing:NEW PARENT %u COST %u RSSI %d\n", current_parent, current_hops_to_sink, current_rssi_to_parent );
    // Inform neighboring nodes after a random time
    call InfoTimer.startOneShot(BEACON_INFO_TIME + (call Random.rand16()) % BEACON_INFO_RESCHEDULING);
	call NotificationTimer.startOneShot(BEACON_REPEAT_PERIOD + (call Random.rand16())% BEACON_REPEAT_RESCHEDULING);
}

// b == a:  0
// b is newer than a:  1
// b is older than a: -1
int compare_seqn(uint8_t a, uint8_t b) {
	// Since the seqnum wraps around zero, and we can receive outdated beacons or lose
	// several beacons, we need to decide what difference of the seqnums should be considered
	// positive and which -- negative.
	//
	// Here we assume that it is more probable to lose 250 beacons than to receive a very old beacon
	// (with a sequence number smaller than the current one by more than 5).
	uint8_t d = b-a;
	if (d == 0)
		return 0;
	else if (d > 250)  // the difference is in range [-5; -1]: considering it as an old beacon
		return -1;
	else
		return 1; 	   // considering the difference positive in range [0; 250]                          
}

bool checkIfNodeInRoutingTable(uint8_t child, uint8_t father)
{
	uint8_t i=0;
	for(i=0;i< routingTableIndex; i++)
	{
		if(routingTable[i].childAddress == child)
			return TRUE;
	}
	return FALSE;
}

void updateRoutingTable(uint8_t child, uint8_t father)
{
	uint8_t i=0;
	for(i=0;i< routingTableIndex; i++)
	{
		if(routingTable[i].childAddress == child)
		{
			routingTable[i].childAddress = child;
			routingTable[i].parentAddress = father;
		}			
	}
}

void insertNodeInRoutingTable(uint8_t child, uint8_t father)
{
	routingTable[routingTableIndex].childAddress=child;
	routingTable[routingTableIndex].parentAddress=father;
	routingTableIndex++;
}

void printRoutingTable()
{
	uint8_t i;
	for(i=0;i < routingTableIndex;i++)
	{
		printf("[INFO] RoutingTable at position %d, is %d %d \n",i, routingTable[i].childAddress, routingTable[i].parentAddress);
	}
}
event message_t* InfoToRootReceiver.receive(message_t*msg, void* payload, uint8_t len)
{
	InfoBeacon* receiveInfoBeacon;
	receiveInfoBeacon = (InfoBeacon*)payload;
	if(len != sizeof(InfoBeacon))
	{
		printf("Receive failed, lenght does not match\n");
		return msg;
	}
	if(TOS_NODE_ID==1)
	{
	printf("[INFO] I'm the source, I've received an info packet from %d\n", receiveInfoBeacon->child);
		if(checkIfNodeInRoutingTable(receiveInfoBeacon->child, receiveInfoBeacon->father))
		{
			updateRoutingTable(receiveInfoBeacon->child, receiveInfoBeacon->father);
		}
		else
		{
			insertNodeInRoutingTable(receiveInfoBeacon->child, receiveInfoBeacon->father);
		}
		return msg;
	}
//	printf("[INFO] I'm not the root, I will forward the message to my parent, the source of the message is %d and the destination is the root\n", receiveInfoBeacon->child);
	createInfoBeacon(receiveInfoBeacon->child, receiveInfoBeacon->father);
	//TODO implement the receiving of a info message, check if i'm the root
	return msg;
}
event message_t* BeaconReceive.receive(message_t* msg, void* payload, uint8_t len) {
	if (i_am_sink)
		return msg; // ignore all incoming beacons on the sink
	
    if (len == sizeof(CollectionBeacon)) {
      int cmp;
      uint16_t hops_to_sink_through_sender;
      int rssi_to_sender;

	  CollectionBeacon* beacon = (CollectionBeacon*) payload;
	  if (beacon->metric >= MAX_METRIC)
		  return msg; // otherwise it will wrap to zero
	  
      hops_to_sink_through_sender = beacon->metric + 1;
      rssi_to_sender = getRssi(msg);
      num_received++;
     // printf("routing:Received beacon from %u seqn %u hops %u RSSI %d\n", call AMPacket.source(msg), beacon->seq_no, hops_to_sink_through_sender, rssi_to_sender); 

	  if (rssi_to_sender < RSSI_THRESHOLD) {
	//	printf("routing:Ignoring the beacon, too weak signal\n"); 
	  	return msg;
	  }
	  
      cmp = compare_seqn(current_seq_no, beacon->seq_no); 
	  if  (cmp < 0) // old seq_no, ignoring it
        return msg; 
	  else if (cmp > 0){ // newer seq_no, we are rebuilding the tree
       // printf("routing:New seqn: rebuilding the tree\n"); 
        current_seq_no = beacon->seq_no;
        updateParent(call AMPacket.source(msg), hops_to_sink_through_sender, rssi_to_sender);
      } else { /* same seq_no */
       if (current_hops_to_sink > hops_to_sink_through_sender){
         // printf("routing:Same seqn, found a parent with a better metric\n"); 
          updateParent(call AMPacket.source(msg), hops_to_sink_through_sender, rssi_to_sender);
        }
        else if ((current_hops_to_sink == hops_to_sink_through_sender) && (current_rssi_to_parent < rssi_to_sender)){
         // printf("routing:Same seqn, found a parent with the same metric but better RSSI\n"); 
           updateParent(call AMPacket.source (msg), hops_to_sink_through_sender, rssi_to_sender);
        }
      }
    }
    return msg;
}



void createInfoBeacon(uint8_t child_address, uint8_t father_address)
{
	InfoBeacon* infoBeacon;
	if(sending_info){
		infoBeaconToReschedule.childAddress =child_address;
		infoBeaconToReschedule.parentAddress = father_address;
		call InfoTimerRescheduling.startOneShot(call Random.rand16() % 	BEACON_INFO_RESCHEDULING);}
	if (current_parent == TOS_NODE_ID) // we don't have a parent
		return;
	infoBeacon = call InfoToRootSend.getPayload(&info_output, sizeof(InfoBeacon));
	infoBeacon->child = child_address;
	infoBeacon->father = father_address;
	sendInfoBeacon();

}



void sendInfoBeacon()
{
	InfoBeacon* infoBeacon;
	error_t status;
	call PacketLink.setRetries(&info_output, NUM_RETRIES); // important to set it every time
	infoBeacon = call InfoToRootSend.getPayload(&info_output, sizeof(InfoBeacon));
//	printf("[INFO] I'm sending the infoBeacon to the root, I'm %d , the entry that I'm sending is %d,%d\n", TOS_NODE_ID, infoBeacon->child, infoBeacon->father);
	status = call InfoToRootSend.send(current_parent, &info_output, sizeof(InfoBeacon));
	if(status != SUCCESS)
	{
		sending_info = FALSE;
		printf("ERROR CAN NOT SEND INFO BEACON WITH CHILD %d AND FATHER %d I'M %d RESCHEDULING\n", infoBeacon->child, infoBeacon->father, TOS_NODE_ID);
		infoBeaconToReschedule.childAddress = infoBeacon->child;
		infoBeaconToReschedule.parentAddress = infoBeacon->father;
		call InfoTimerRescheduling.startOneShot(call Random.rand16() % BEACON_INFO_RESCHEDULING);
	}
	else{
		sending_info = TRUE;
	}
}

event void InfoTimerRescheduling.fired()
{
	createInfoBeacon(infoBeaconToReschedule.childAddress, infoBeaconToReschedule.parentAddress);
}

event void InfoTimer.fired() {
	createInfoBeacon(TOS_NODE_ID, current_parent);
	//TODO: call forwarding info to root
}
event void PrintRoutingTableTimer.fired(){
	printRoutingTable();
}
event void AMControl.startDone(error_t err) {
	if (err != SUCCESS) {
		call AMControl.start();   /* trying again */
	}
}


event void AMControl.stopDone(error_t err) {}

}
