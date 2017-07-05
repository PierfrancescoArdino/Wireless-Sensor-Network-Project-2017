#include "MyCollection.h"

configuration RoutingC
{
  provides interface Routing;
}
implementation
{
  components MainC, RoutingP, ActiveMessageC, LedsC;
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  components new TimerMilliC() as Timer2;
  components new TimerMilliC() as InfoFatherToRootTimer;
  components new TimerMilliC() as InfoTimerResch;
  components new AMSenderC(AM_COLLECTIONBEACON) as BeaconSender;
  components new AMReceiverC(AM_COLLECTIONBEACON) as BeaconReceiver;
  components new AMSenderC(AM_SENDTOSOURCEBEACON) as InfoFatherToRootSender;
  components new AMReceiverC(AM_SENDTOSOURCEBEACON) as InfoFatherToRootReceiver;
  components new AMSenderC(AM_COLLECTIONDATA) as DataSender;
  components new AMReceiverC(AM_COLLECTIONDATA) as DataReceiver;
  components RandomC;
  components CC2420PacketC;
  RoutingP.CC2420Packet -> CC2420PacketC;
  components PacketLinkC;

  Routing = RoutingP.Routing;
  
  RoutingP -> MainC.Boot;
  RoutingP.NotificationTimer -> Timer0;
  RoutingP.RefreshTimer -> Timer1;
  RoutingP.RelayTimer -> Timer2;
  RoutingP.InfoTimer -> InfoFatherToRootTimer;
  RoutingP.InfoTimerRescheduling -> InfoTimerResch;
  RoutingP.Leds -> LedsC;
  RoutingP.AMPacket -> ActiveMessageC;
  RoutingP.BeaconSend -> BeaconSender;
  RoutingP.BeaconReceive -> BeaconReceiver;
  RoutingP.InfoToRootSend -> InfoFatherToRootSender;
  RoutingP.InfoToRootReceiver -> InfoFatherToRootReceiver;
  RoutingP.DataSend -> DataSender;
  RoutingP.DataReceive -> DataReceiver;
  RoutingP.Random -> RandomC;
  RoutingP.AMControl -> ActiveMessageC;
  
  RoutingP.PacketLink -> PacketLinkC;
  RoutingP.LPL		  -> ActiveMessageC;
}

