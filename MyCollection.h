#ifndef MYCOLLECTION_H
#define MYCOLLECTION_H

enum {
  AM_COLLECTIONBEACON = 0x88,
  AM_COLLECTIONDATA = 0x99,
};

// beacon packet
typedef nx_struct CollectionBeacon {
  nx_uint8_t seq_no;
  nx_uint16_t metric;
} CollectionBeacon;

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


#endif
