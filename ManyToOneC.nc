configuration ManyToOneC {
	provides interface ManyToOne;
}
implementation{
	components ManyToOneP;
	components MainC, RandomC;
	components PacketLinkC;
	components LedsC;
	components ActiveMessageC;
	components RoutingC as Routing;
	components new AMSenderC(AM_COLLECTIONDATA) as DataSender;
	components new AMReceiverC(AM_COLLECTIONDATA) as DataReceiver;
	components CC2420PacketC;
	components new TimerMilliC() as RetryForwarding;
	
  	ManyToOneP.CC2420Packet -> CC2420PacketC;
	ManyToOne = ManyToOneP.ManyToOne;
	ManyToOneP -> MainC.Boot;
	ManyToOneP.RetryForwardingTimer -> RetryForwarding;
	ManyToOneP.Leds -> LedsC;
	ManyToOneP.AMPacket -> ActiveMessageC;
	ManyToOneP.DataSend -> DataSender;
 	ManyToOneP.DataReceive -> DataReceiver;
 	ManyToOneP.Random -> RandomC;
  	ManyToOneP.AMControl -> ActiveMessageC;
  	ManyToOneP.PacketLink -> PacketLinkC;
  	ManyToOneP.LPL		  -> ActiveMessageC;
	ManyToOneP.Routing -> Routing;
}
