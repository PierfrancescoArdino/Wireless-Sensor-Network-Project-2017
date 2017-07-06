#include <AM.h>
#include "MyCollection.h"

interface ManyToOne {
  command void send(MyData* d);
  event void receive(am_addr_t from, MyData* d);
}
