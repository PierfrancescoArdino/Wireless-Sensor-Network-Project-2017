configuration AppC {
}
implementation {
	components RoutingC as Routing;
	components ManyToOneC as ManyToOne;
	components OneToManyC as OneToMany;
	components AppP;
	components SerialPrintfC, SerialStartC;
	components new TimerMilliC() as StartTimer;
	components new TimerMilliC() as PeriodicTimer;
	components new TimerMilliC() as JitterTimer;
	components MainC, RandomC;

	AppP.Boot -> MainC;
	AppP.Routing -> Routing;
	AppP.ManyToOne -> ManyToOne;
	AppP.OneToMany -> OneToMany;
	AppP.Random -> RandomC;
	AppP.StartTimer -> StartTimer;
	AppP.PeriodicTimer -> PeriodicTimer;
	AppP.JitterTimer -> JitterTimer;
}
