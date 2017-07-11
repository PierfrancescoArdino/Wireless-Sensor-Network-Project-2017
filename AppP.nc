#include <Timer.h>
#include "MyCollection.h"
#include <AM.h>
#include <printf.h>
module AppP {
	uses interface Routing;
	uses interface ManyToOne;
	uses interface OneToMany;
	uses interface Boot;
	uses interface Timer<TMilli> as StartTimer;
	uses interface Timer<TMilli> as PeriodicTimer;
	uses interface Timer<TMilli> as JitterTimer;
	uses interface Random;
}
implementation
{
#define MANY_TO_ONE (60*1024L)
#define ONE_TO_MANY (100*1024L)
#define JITTER (40*1024L)
#define JITTER2 (50*1024L)

	MyData data;
	
	event void Boot.booted() {
		call StartTimer.startOneShot(10*1024);
	}

	event void StartTimer.fired() {
		if (TOS_NODE_ID == 1) {
			call Routing.buildTree();
			call PeriodicTimer.startPeriodic(ONE_TO_MANY);
		}
		else {
			call PeriodicTimer.startPeriodic(MANY_TO_ONE);
		}
	}

	event void PeriodicTimer.fired() {
		if (TOS_NODE_ID ==1)
			call JitterTimer.startOneShot(call Random.rand16() % JITTER);
		else
			call JitterTimer.startOneShot(call Random.rand16() % JITTER2);
	}

	event void JitterTimer.fired() {
		if(data.seqn<200)
		{
			if(TOS_NODE_ID == 1){
				uint8_t destNode = call Routing.getRandomNode();
				printf("app:Send to node %d seqn %d\n", destNode, data.seqn);
				call OneToMany.send(&data, destNode);
				data.seqn++;
			}
			else{
				printf("app:Send to sink seqn %d\n", data.seqn);
				call ManyToOne.send(&data);
				data.seqn++;

			}
		}
	}
	event void ManyToOne.receive(am_addr_t from, MyData* d) {
		printf("app:Recv from %d seqn %d\n", from, d->seqn);
	}
	event void OneToMany.receive(MyData* d) {
		printf("app:Recv from sink seqn %d\n", d->seqn);
	}
}
