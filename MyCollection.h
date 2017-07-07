#ifndef MYCOLLECTION_H
#define MYCOLLECTION_H

enum {
  AM_COLLECTIONBEACON = 0x88,
  AM_SENDTOSOURCEBEACON = 0x89,
  AM_COLLECTIONDATA = 0x99,
  AM_SINKDATA = 0x98,
  MAX_ROUTE_LENGTH = 30,
};

// beacon packet
typedef nx_struct CollectionBeacon {
  nx_uint8_t seq_no;
  nx_uint16_t metric;
} CollectionBeacon;
typedef nx_struct InfoBeacon {
	nx_uint8_t child;
	nx_uint8_t father;
} InfoBeacon;
// application-level data packet
typedef nx_struct {
	nx_uint16_t seqn;
} MyData;

// network-level data packet
typedef nx_struct {
  nx_uint16_t from;
  nx_uint16_t hops;
  MyData data; // includes the app-level data
} CollectionData;

typedef struct RoutingTableStruct{
	uint8_t childAddress;
	uint8_t parentAddress;
} RoutingTableStruct;

typedef nx_struct {
	nx_uint16_t finalDest;
	MyData data;
	nx_uint8_t destRoute[MAX_ROUTE_LENGTH];
} DataFromSink;

#endif
