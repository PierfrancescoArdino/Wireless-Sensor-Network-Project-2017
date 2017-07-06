#include <Timer.h>
#include "MyCollection.h"
#include <AM.h>
#include <printf.h>
module AppP {
	uses interface Routing;
	uses interface ManyToOne;
	uses interface Boot;
	uses interface Timer<TMilli> as StartTimer;
	uses interface Timer<TMilli> as PeriodicTimer;
	uses interface Timer<TMilli> as JitterTimer;
	uses interface Random;
}
implementation
{
#define IMI (60*1024L)
#define JITTER (50*1024L)

	MyData data;
	
	event void Boot.booted() {
		call StartTimer.startOneShot(10*1024);
	}

	event void StartTimer.fired() {
		if (TOS_NODE_ID == 1) {
			call Routing.buildTree();
		}
		else {
			// TODO: uncomment the following to enable sending data
			call PeriodicTimer.startPeriodic(IMI);
		}
	}

	event void PeriodicTimer.fired() {
		call JitterTimer.startOneShot(call Random.rand16() % JITTER);
	}

	event void JitterTimer.fired() {
		if(data.seqn<40)
		{	
			printf("app:Send to sink seqn %d\n", data.seqn);
			call ManyToOne.send(&data);
			data.seqn++;
		}
	}
	event void ManyToOne.receive(am_addr_t from, MyData* d) {
		printf("app:Recv from %d seqn %d\n", from, d->seqn);
	}
}
