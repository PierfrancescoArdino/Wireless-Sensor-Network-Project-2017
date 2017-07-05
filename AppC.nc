configuration AppC {
}
implementation {
	components RoutingC as CollectionC;
	//components CtpAdapterC as CollectionC;
	components AppP;
	components SerialPrintfC, SerialStartC;
	components new TimerMilliC() as StartTimer;
	components new TimerMilliC() as PeriodicTimer;
	components new TimerMilliC() as JitterTimer;
	components MainC, RandomC;

	AppP.Boot -> MainC;
	AppP.Routing -> CollectionC;
	AppP.Random -> RandomC;
	AppP.StartTimer -> StartTimer;
	AppP.PeriodicTimer -> PeriodicTimer;
	AppP.JitterTimer -> JitterTimer;
}
