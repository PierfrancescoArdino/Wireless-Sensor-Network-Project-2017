#include <AM.h>
#include "MyCollection.h"

interface Routing {
	command void buildTree();
	command uint8_t getParent();
	command uint8_t getRandomNode();
	command uint8_t* getDestinationRoute(uint8_t destinationNode);
}
