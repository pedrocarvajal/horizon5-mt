#ifndef __CONSTANTS_CO_MESSAGE_BUS_MQH__
#define __CONSTANTS_CO_MESSAGE_BUS_MQH__

#define MB_CHANNEL_CONNECTOR "connector"
#define MB_CHANNEL_PERSISTENCE "persistence"
#define MB_CHANNEL_EVENTS_IN "events_inbound"
#define MB_CHANNEL_EVENTS_OUT "events_outbound"
#define MB_CHANNEL_EVENTS_SERVICE "events_service"

#define MB_SERVICE_MONITOR "monitor"
#define MB_SERVICE_GATEWAY "gateway"
#define MB_SERVICE_PERSISTENCE "persistence"

#define MB_TYPE_ACK_EVENT "ack_event"
#define MB_TYPE_HTTP_POST "http_post"
#define MB_TYPE_FLUSH "flush"

#define MB_PAYLOAD_BUFFER_SIZE 65536
#define MB_TYPE_BUFFER_SIZE 256

#endif
