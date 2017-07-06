#include <AM.h>
#include "MyCollection.h"

interface Routing {
	command void buildTree();
	command uint8_t getParent();
}
