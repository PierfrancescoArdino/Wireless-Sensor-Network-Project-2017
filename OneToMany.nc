#include <AM.h>
#include "MyCollection.h"

interface OneToMany {
  command void send(MyData* d, uint8_t destNode);
  event void receive(MyData* d);
}
