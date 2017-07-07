configuration OneToManyC {
	provides interface OneToMany;
}
implementation{
	components OneToManyP;
	components MainC, RandomC;
	components PacketLinkC;
	components LedsC;
	components ActiveMessageC;
	components RoutingC as Routing;
	components new AMSenderC(AM_SINKDATA) as DataFromSinkSender;
	components new AMReceiverC(AM_SINKDATA) as DataFromSinkReceiver;
	components CC2420PacketC;
	components new TimerMilliC() as RetryForwarding;
	
  	OneToManyP.CC2420Packet -> CC2420PacketC;
	OneToMany = OneToManyP.OneToMany;
	OneToManyP -> MainC.Boot;
	OneToManyP.RetryForwarding -> RetryForwarding;
	OneToManyP.Leds -> LedsC;
	OneToManyP.AMPacket -> ActiveMessageC;
	OneToManyP.DataFromSinkSend -> DataFromSinkSender;
 	OneToManyP.DataFromSinkReceive -> DataFromSinkReceiver;
 	OneToManyP.Random -> RandomC;
  	OneToManyP.AMControl -> ActiveMessageC;
  	OneToManyP.PacketLink -> PacketLinkC;
  	OneToManyP.LPL		  -> ActiveMessageC;
	OneToManyP.Routing -> Routing;
}
