#include <AM.h>
#include "MyCollection.h"

interface Routing {
  command void buildTree();
  command void send(MyData* d);
  event void receive(am_addr_t from, MyData* d);
}
